import AVFoundation
import Foundation
import os

private let log = Logger(subsystem: "com.broadcastbrain.mac", category: "audio")

enum AudioError: Error, LocalizedError {
    case micPermissionDenied
    case engineStartFailed(Error)
    case formatConversionFailed

    var errorDescription: String? {
        switch self {
        case .micPermissionDenied: return "Microphone permission denied"
        case .engineStartFailed(let e): return "Audio engine failed to start: \(e.localizedDescription)"
        case .formatConversionFailed: return "Audio format conversion failed (16 kHz mono)"
        }
    }
}

/// Always-on mic capture with energy-based VAD.
///
/// Converts raw PCM from AVAudioEngine to 16 kHz mono Float32, detects
/// utterance boundaries via RMS energy thresholds, writes each utterance
/// to a temp WAV file, and fires `onUtterance(path)` for Gemma 4 audio
/// inference — no Apple Speech framework involved.
///
/// Emits:
///   - onUtterance(path): WAV file path for each completed utterance
///   - onError(err): unrecoverable errors only
final class AudioCaptureService {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var isRunning = false

    // MARK: - PCM accumulator
    private let targetSampleRate: Double = 16_000
    private var audioBuffer: [Float] = []
    /// Max buffer: 65 seconds @ 16 kHz
    private let maxBufferSamples = 16_000 * 65

    // MARK: - Energy VAD state
    /// Window = 100 ms @ 16 kHz
    private let windowSamples = 1_600
    /// How many complete windows we have processed from audioBuffer[0]
    private var processedWindowCount = 0

    private var isSpeaking = false
    /// audioBuffer index where the current utterance started
    private var speechStartSample = 0
    /// Candidate start before enough speech windows confirm onset
    private var pendingSpeechStartSample = 0

    private var speechWindowsBeforeStart = 0
    private var silentWindowsAfterSpeech = 0

    // Thresholds & timing
    private let speechThreshold: Float  = 0.01   // RMS to detect voice
    private let silenceThreshold: Float = 0.005  // RMS below → silence
    private let speechOnWindows  = 2             // 200 ms sustained → start
    private let silenceOffWindows = 8            // 800 ms sustained → end
    private let minUtteranceSamples = 8_000      // 500 ms minimum utterance
    private let maxUtteranceSamples = 16_000 * 15 // 15 s max before force-flush

    // MARK: - Callbacks
    var onUtterance: ((String) -> Void)?
    var onError: ((AudioError) -> Void)?

    // MARK: - Permissions

    func requestPermissions() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .authorized { return }
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
        }
        guard granted else { throw AudioError.micPermissionDenied }
    }

    // MARK: - Lifecycle

    func start() throws {
        guard !isRunning else { return }

        let input = engine.inputNode
        engine.prepare()

        let inputFormat = input.outputFormat(forBus: 0)
        log.info("input format: sr=\(inputFormat.sampleRate) ch=\(inputFormat.channelCount)")

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        )!

        guard let conv = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioError.formatConversionFailed
        }
        self.converter = conv

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buf, _ in
            guard let self, let conv = self.converter else { return }
            self.processTap(buffer: buf, converter: conv, targetFormat: targetFormat)
        }

        do {
            try engine.start()
            log.info("audio engine started (target=16 kHz mono Float32)")
        } catch {
            input.removeTap(onBus: 0)
            throw AudioError.engineStartFailed(error)
        }

        isRunning = true
    }

    func stop() {
        log.info("stop()")
        isRunning = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        converter = nil
        audioBuffer.removeAll()
        resetVADState()
    }

    // MARK: - Tap → PCM conversion

    private func processTap(buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        let ratio = targetSampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 1
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var inputConsumed = false
        var convError: NSError?
        converter.convert(to: out, error: &convError) { _, outStatus in
            if inputConsumed { outStatus.pointee = .noDataNow; return nil }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard convError == nil, out.frameLength > 0,
              let ch = out.floatChannelData else { return }

        let samples = Array(UnsafeBufferPointer(start: ch[0], count: Int(out.frameLength)))
        DispatchQueue.main.async { [weak self] in
            self?.appendSamples(samples)
        }
    }

    // MARK: - PCM accumulation + VAD

    private func appendSamples(_ samples: [Float]) {
        audioBuffer.append(contentsOf: samples)
        trimBuffer()
        processWindows()
    }

    /// Trim already-processed audio to stay within the max buffer size.
    private func trimBuffer() {
        let processedSamples = processedWindowCount * windowSamples
        let excess = audioBuffer.count - maxBufferSamples
        guard excess > 0, processedSamples > 0 else { return }

        // Only trim complete, already-processed windows
        let trimWindows = min(excess / windowSamples, processedWindowCount)
        guard trimWindows > 0 else { return }
        let trimCount = trimWindows * windowSamples

        if isSpeaking {
            speechStartSample = max(0, speechStartSample - trimCount)
            pendingSpeechStartSample = max(0, pendingSpeechStartSample - trimCount)
        }
        audioBuffer.removeFirst(trimCount)
        processedWindowCount -= trimWindows
    }

    private func processWindows() {
        while (processedWindowCount + 1) * windowSamples <= audioBuffer.count {
            let start = processedWindowCount * windowSamples
            let end = start + windowSamples
            let slice = audioBuffer[start..<end]
            let sumSq = slice.reduce(Float(0)) { $0 + $1 * $1 }
            let rms = sqrt(sumSq / Float(windowSamples))
            processVADWindow(rms: rms, windowEnd: end)
            processedWindowCount += 1
        }
    }

    private func processVADWindow(rms: Float, windowEnd: Int) {
        if !isSpeaking {
            if rms > speechThreshold {
                if speechWindowsBeforeStart == 0 {
                    pendingSpeechStartSample = processedWindowCount * windowSamples
                }
                speechWindowsBeforeStart += 1
                if speechWindowsBeforeStart >= speechOnWindows {
                    isSpeaking = true
                    speechStartSample = pendingSpeechStartSample
                    silentWindowsAfterSpeech = 0
                    log.debug("VAD: speech onset at sample \(self.speechStartSample)")
                }
            } else {
                speechWindowsBeforeStart = 0
            }
        } else {
            if rms < silenceThreshold {
                silentWindowsAfterSpeech += 1
                if silentWindowsAfterSpeech >= silenceOffWindows {
                    let end = windowEnd
                    flushUtterance(endSample: end)
                }
            } else {
                silentWindowsAfterSpeech = 0
                // Force-flush at max utterance length
                let elapsed = windowEnd - speechStartSample
                if elapsed >= maxUtteranceSamples {
                    log.debug("VAD: force-flush at max length (\(elapsed) samples)")
                    flushUtterance(endSample: windowEnd)
                    // Resume as if still speaking (continuous loud audio)
                    isSpeaking = true
                    speechStartSample = windowEnd
                    silentWindowsAfterSpeech = 0
                }
            }
        }
    }

    private func flushUtterance(endSample: Int) {
        let start = speechStartSample
        let end = min(endSample, audioBuffer.count)
        guard end > start else {
            resetVADState()
            return
        }
        let samples = Array(audioBuffer[start..<end])
        let durationS = Double(samples.count) / targetSampleRate

        if samples.count < minUtteranceSamples {
            log.debug("VAD: utterance too short (\(String(format: "%.2f", durationS))s), discarding")
        } else {
            log.info("VAD: utterance \(String(format: "%.2f", durationS))s → writing WAV")
            do {
                let path = try writeWAV(samples: samples)
                onUtterance?(path)
            } catch {
                log.error("WAV write failed: \(error.localizedDescription)")
            }
        }
        resetVADState()
    }

    private func resetVADState() {
        isSpeaking = false
        speechStartSample = 0
        pendingSpeechStartSample = 0
        speechWindowsBeforeStart = 0
        silentWindowsAfterSpeech = 0
    }

    // MARK: - WAV writer

    /// Write Float32 samples to a 16-bit PCM WAV file in the temp directory.
    ///
    /// Hand-rolled because AVAudioFile inserts a `JUNK` padding chunk between
    /// `WAVE` and `fmt `, and Cactus's WAV parser expects `fmt ` immediately
    /// after `WAVE` ("Missing fmt chunk" otherwise).
    private func writeWAV(samples: [Float]) throws -> String {
        let name = "utterance_\(Int(Date().timeIntervalSince1970 * 1000)).wav"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)

        let sampleRate = UInt32(targetSampleRate)
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign: UInt16 = channels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count) * UInt32(blockAlign)
        let riffSize = 36 + dataSize // 4 ("WAVE") + 24 (fmt chunk) + 8 (data header) + data

        var data = Data()
        data.reserveCapacity(44 + Int(dataSize))

        func appendLE<T: FixedWidthInteger>(_ v: T) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        appendLE(UInt32(riffSize))
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        data.append(contentsOf: [0x66, 0x6d, 0x74, 0x20]) // "fmt "
        appendLE(UInt32(16))                              // fmt chunk size (PCM)
        appendLE(UInt16(1))                               // audio format: PCM
        appendLE(channels)
        appendLE(sampleRate)
        appendLE(byteRate)
        appendLE(blockAlign)
        appendLE(bitsPerSample)
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        appendLE(dataSize)

        // Float32 [-1.0, 1.0] → Int16 little-endian
        data.append(Data(count: Int(dataSize)))
        data.withUnsafeMutableBytes { raw in
            let int16Base = raw.baseAddress!.advanced(by: 44).assumingMemoryBound(to: Int16.self)
            for i in 0..<samples.count {
                let clipped = max(-1.0, min(1.0, samples[i]))
                int16Base[i] = Int16(clipped * 32767.0)
            }
        }

        try data.write(to: url, options: .atomic)
        log.debug("WAV: \(url.lastPathComponent) (\(samples.count) frames)")
        return url.path
    }
}

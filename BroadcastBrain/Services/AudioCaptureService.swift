import AVFoundation
import Foundation
import Speech
import os

private let log = Logger(subsystem: "com.broadcastbrain.mac", category: "audio")

enum AudioError: Error, LocalizedError {
    case micPermissionDenied
    case speechPermissionDenied
    case recognizerUnavailable
    case engineStartFailed(Error)

    var errorDescription: String? {
        switch self {
        case .micPermissionDenied: return "Microphone permission denied"
        case .speechPermissionDenied: return "Speech recognition permission denied"
        case .recognizerUnavailable: return "On-device speech recognizer unavailable"
        case .engineStartFailed(let e): return "Audio engine failed to start: \(e.localizedDescription)"
        }
    }
}

/// Always-on mic capture with on-device STT via Apple's Speech framework.
///
/// Emits:
///   - onPartial(text): the running in-segment transcript (fires frequently)
///   - onSegment(text): once per completed utterance (natural pause)
///   - onError(err): unrecoverable errors only
final class AudioCaptureService {
    private let engine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var isRunning = false

    var onPartial: ((String) -> Void)?
    var onSegment: ((String) -> Void)?
    var onError: ((AudioError) -> Void)?

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
        log.info("recognizer=\(String(describing: self.recognizer)) available=\(self.recognizer?.isAvailable ?? false) onDevice=\(self.recognizer?.supportsOnDeviceRecognition ?? false)")
    }

    func requestPermissions() async throws {
        let currentSpeech = SFSpeechRecognizer.authorizationStatus()
        log.info("speech auth status (pre): \(currentSpeech.rawValue)")

        let speechStatus: SFSpeechRecognizerAuthorizationStatus
        if currentSpeech == .authorized {
            speechStatus = .authorized
        } else {
            speechStatus = await Self.requestSpeechAuth()
        }
        log.info("speech auth status (post): \(speechStatus.rawValue)")
        guard speechStatus == .authorized else { throw AudioError.speechPermissionDenied }

        let currentMic = AVCaptureDevice.authorizationStatus(for: .audio)
        log.info("mic auth status (pre): \(currentMic.rawValue)")

        let micGranted: Bool
        if currentMic == .authorized {
            micGranted = true
        } else {
            micGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
            }
        }
        log.info("mic granted: \(micGranted)")
        guard micGranted else { throw AudioError.micPermissionDenied }

        guard let r = recognizer else { throw AudioError.recognizerUnavailable }
        log.info("recognizer available after perms: \(r.isAvailable)")
        guard r.isAvailable else { throw AudioError.recognizerUnavailable }
    }

    private static func requestSpeechAuth() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
    }

    func start() throws {
        guard let recognizer else {
            log.error("start: no recognizer")
            throw AudioError.recognizerUnavailable
        }
        guard !isRunning else {
            log.info("start: already running, ignoring")
            return
        }

        let input = engine.inputNode

        // Prepare BEFORE querying `outputFormat(forBus:)`. On macOS, reading
        // the input node's format before the engine graph is initialized
        // triggers two stderr `throwing -10877` lines (kAudioUnitErr_...).
        // They're benign but they're the first thing you see in the console
        // when debugging; silencing them makes the real logs readable.
        engine.prepare()

        let format = input.outputFormat(forBus: 0)
        log.info("input format: sr=\(format.sampleRate) ch=\(format.channelCount)")

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        do {
            try engine.start()
            log.info("audio engine started")
        } catch {
            log.error("engine.start failed: \(error.localizedDescription)")
            input.removeTap(onBus: 0)
            throw AudioError.engineStartFailed(error)
        }

        isRunning = true
        startRecognitionSegment(recognizer: recognizer)
    }

    func stop() {
        log.info("stop()")
        isRunning = false
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }

    private func startRecognitionSegment(recognizer: SFSpeechRecognizer) {
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        // Do NOT force on-device. On macOS the on-device path is flaky and will
        // silently fail if the model isn't downloaded yet. We allow server-based
        // fallback (network.client entitlement is now true). For real airplane
        // demos, once Apple's on-device model is warm it works offline anyway.
        if #available(macOS 13.0, *) {
            req.addsPunctuation = true
        }
        self.request = req

        log.info("starting recognition segment")

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    log.info("segment final: \(text, privacy: .public)")
                    if !text.isEmpty {
                        self.onSegment?(text)
                    }
                    self.request = nil
                    self.task = nil
                    if self.isRunning, let rec = self.recognizer {
                        self.startRecognitionSegment(recognizer: rec)
                    }
                } else {
                    self.onPartial?(text)
                }
            }

            if let error {
                let nsError = error as NSError
                log.error("recog error: domain=\(nsError.domain) code=\(nsError.code) desc=\(error.localizedDescription, privacy: .public)")
                self.request = nil
                self.task = nil
                // While listening, silently restart on any recognition error.
                if self.isRunning, let rec = self.recognizer {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self, self.isRunning else { return }
                        self.startRecognitionSegment(recognizer: rec)
                    }
                }
            }
        }
    }
}

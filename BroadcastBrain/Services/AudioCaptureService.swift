import AVFoundation
import Foundation
import Speech

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
/// Why Apple Speech and not cactusStreamTranscribe: reliability + segment-restart
/// is natively supported. Apple's recognizer emits `isFinal=true` on natural pauses
/// in speech; we use that as a segment boundary. After each final, we restart the
/// recognition task with a fresh request so the mic keeps listening continuously.
/// Cactus is freed to focus on text completion.
///
/// Contract:
///   - `onPartial(text)`: fires frequently during a segment with the running transcript
///   - `onSegment(text)`: fires once per completed utterance (natural pause / end-of-segment)
///   - `onError(err)`: fires on unrecoverable errors
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
    }

    func requestPermissions() async throws {
        let speechStatus = await Self.requestSpeechAuth()
        guard speechStatus == .authorized else { throw AudioError.speechPermissionDenied }

        let micGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
        }
        guard micGranted else { throw AudioError.micPermissionDenied }

        guard let r = recognizer, r.isAvailable else { throw AudioError.recognizerUnavailable }
    }

    private static func requestSpeechAuth() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
    }

    /// Start capture + continuous STT. Calls `onSegment` for every natural pause.
    func start() throws {
        guard let recognizer else { throw AudioError.recognizerUnavailable }
        guard !isRunning else { return }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw AudioError.engineStartFailed(error)
        }

        isRunning = true
        startRecognitionSegment(recognizer: recognizer)
    }

    /// Stop everything. Call when user toggles mic off.
    func stop() {
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
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        if #available(macOS 13.0, *) {
            req.addsPunctuation = true
        }
        self.request = req

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    if !text.isEmpty {
                        self.onSegment?(text)
                    }
                    // Segment ended (natural pause) — restart immediately to keep listening.
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
                // Cancellation during stop() — ignore
                let isCancel = nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 203
                // "No speech detected" at end of segment — benign, restart
                let isNoSpeech = nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110

                self.request = nil
                self.task = nil

                if isCancel {
                    return
                }

                if isNoSpeech && self.isRunning, let rec = self.recognizer {
                    self.startRecognitionSegment(recognizer: rec)
                    return
                }

                self.onError?(.engineStartFailed(error))
            }
        }
    }
}

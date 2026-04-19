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

/// Mic capture + on-device STT via Apple's Speech framework.
///
/// Why Apple Speech and not cactusStreamTranscribe: reliability. Apple's recognizer
/// has on-device support on macOS 14+ and is battle-tested. We free Cactus to focus
/// on the text completion step. This also means MOCK_MODE demos work end-to-end
/// without the Cactus SDK integrated at all.
final class AudioCaptureService {
    private let engine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Called with partial transcripts while recording.
    var onPartial: ((String) -> Void)?
    /// Called once with the final transcript on stop. If no speech detected, empty string.
    var onFinal: ((String) -> Void)?
    /// Called on any error after start.
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

    func start() throws {
        guard let recognizer else { throw AudioError.recognizerUnavailable }

        // Clean state from any prior run
        task?.cancel()
        task = nil

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if #available(macOS 13.0, *), recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        self.request = req

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

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    self.onFinal?(text)
                    self.cleanup()
                } else {
                    self.onPartial?(text)
                }
            }
            if let error {
                // Cancelled during stop() is expected; ignore unless it's a real failure
                let nsError = error as NSError
                if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 203 {
                    self.onError?(.engineStartFailed(error))
                }
                self.cleanup()
            }
        }
    }

    /// Call on user release. Triggers end-of-speech and fires `onFinal`.
    func stop() {
        request?.endAudio()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }

    private func cleanup() {
        task = nil
        request = nil
    }
}

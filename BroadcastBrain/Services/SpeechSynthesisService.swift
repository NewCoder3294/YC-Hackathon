import AVFoundation
import Foundation
import os

private let log = Logger(subsystem: "com.broadcastbrain.mac", category: "tts")

/// Injectable so tests can spy on TTS without firing `AVSpeechSynthesizer`.
protocol SpeechSynthesizing: AnyObject {
    var isSpeaking: Bool { get }
    func speak(_ text: String)
    func stop()
}

/// Thin wrapper over `AVSpeechSynthesizer` used by the WhisperEngine to read
/// agent whispers aloud. Interrupts any in-flight utterance so slow whispers
/// don't stack across 30-second ticks.
///
/// Also exposes `isEchoLikely` — the mic captures our own TTS output through
/// the speakers, which STT happily transcribes. The live pipeline consults
/// this flag to drop partial/final segments while we're speaking (plus a
/// short cooldown after) so Gemma doesn't get fed its own voice.
final class SpeechSynthesisService: NSObject, SpeechSynthesizing, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private var lastFinishedAt: Date?
    /// Keep the mic gated for this long after TTS ends — covers the trailing
    /// audio-tail + SFSpeechRecognizer's partial buffer still draining.
    private let postSpeechCooldown: TimeInterval = 1.5

    override init() {
        super.init()
        synth.delegate = self
    }

    var isSpeaking: Bool { synth.isSpeaking }

    /// True while TTS is speaking OR within the post-speech cooldown. The
    /// live-transcript pipeline uses this to suppress self-echo.
    var isEchoLikely: Bool {
        if synth.isSpeaking { return true }
        if let t = lastFinishedAt, Date().timeIntervalSince(t) < postSpeechCooldown {
            return true
        }
        return false
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        log.info("speak: \(trimmed, privacy: .public)")
        synth.speak(utterance)
    }

    func stop() {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        lastFinishedAt = Date()
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        lastFinishedAt = Date()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        lastFinishedAt = Date()
    }
}

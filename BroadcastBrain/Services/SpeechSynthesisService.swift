import AVFoundation
import Foundation
import os

private let log = Logger(subsystem: "com.broadcastbrain.mac", category: "tts")

/// Thin wrapper over `AVSpeechSynthesizer` used by the WhisperEngine to read
/// agent whispers aloud. Interrupts any in-flight utterance so slow whispers
/// don't stack across 30-second ticks.
final class SpeechSynthesisService {
    private let synth = AVSpeechSynthesizer()

    var isSpeaking: Bool { synth.isSpeaking }

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
    }
}

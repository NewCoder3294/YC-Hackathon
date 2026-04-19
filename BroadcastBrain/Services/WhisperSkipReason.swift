import Foundation

/// Why the last `WhisperEngine.tickOnce` bailed without appending a stat card.
///
/// Each case maps to a specific point in the tick where we gave up. Surfaced
/// on `AppStore.lastWhisperSkip` so the UI can show "armed but…" and make the
/// invisible visible — previously every skip produced nothing but a debug log.
enum WhisperSkipReason: Equatable {
    /// No live play-by-play feed is attached (or the feed hasn't polled
    /// anything yet). Cactus was never called this tick.
    case noPlays

    /// Gemma was called and returned `{"no_verified_data":true}`. Usually
    /// means the prompt + plays didn't give the model enough grounding for a
    /// specific stat.
    case noVerifiedData

    /// Gemma's JSON had an empty `answer` field.
    case emptyAnswer

    /// Gemma's reply didn't contain extractable JSON. The salvager could not
    /// recover a whisper sentence.
    case unparseable

    /// Cactus threw. `message` surfaces the underlying error's description
    /// so the UI can be specific ("Cactus init failed: gemma.gguf missing"
    /// vs "Completion timed out").
    case cactusError(message: String)

    /// Short label suitable for a UI footer. Not localized — dev tool.
    var displayText: String {
        switch self {
        case .noPlays:        return "waiting on live feed"
        case .noVerifiedData: return "no grounded stat this tick"
        case .emptyAnswer:    return "Gemma returned empty answer"
        case .unparseable:    return "Gemma reply had no JSON"
        case .cactusError(let m): return "Cactus error: \(m)"
        }
    }
}

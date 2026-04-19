import Foundation

/// Pulls complete sentences out of the cumulative transcript emitted by
/// `SFSpeechRecognizer`, deduplicating on canonical form so we don't re-emit
/// the same sentence when Apple's recognizer revises earlier words.
///
/// Why a Set and not a prefix-match:
///
/// Apple's STT frequently revises partials as more audio arrives:
///
///     P1  "What two teams are playing"
///     P2  "What two teams are playing yeah, I'm just completely fails."
///     P3  "What two teams are playing yeah I'm just completely fails."   ← comma gone
///
/// The original code dedup'd by checking `cumulative.hasPrefix(lastEmitted)`.
/// At P3 the prefix no longer matches (a comma is missing), so the whole
/// string was re-processed and the terminating-period sentence was emitted
/// twice. The teammate's screenshot shows 6 identical cards from exactly this
/// pattern.
///
/// Instead we canonicalize each completed sentence (lowercase + collapse
/// whitespace + drop lightweight punctuation) and keep a Set of forms already
/// emitted in this session. A revised partial that produces the same
/// canonical form is silently skipped.
struct SentenceExtractor {
    /// Canonical forms of every sentence emitted so far this session.
    private var emitted: Set<String> = []

    /// Clear emission history — call when the user explicitly resets the
    /// transcript (Clear button, new match, stop listening). Do NOT call on
    /// SFSpeechRecognitionTask boundaries: the final segment often repeats a
    /// sentence that a partial already shipped, and we want to dedup those.
    mutating func reset() {
        emitted.removeAll(keepingCapacity: true)
    }

    /// Current number of distinct sentences shipped. Exposed so callers can
    /// sanity-check deduplication in diagnostics/logs.
    var emittedCount: Int { emitted.count }

    /// Ingest a cumulative partial/final transcript. Returns any newly
    /// completed sentences that have not been emitted before.
    ///
    /// - Parameters:
    ///   - cumulative: the full text of the current recognition task so far.
    ///   - forceFinal: if true, the trailing text after the last sentence
    ///     boundary is also emitted. Pass true from `SFSpeechRecognizer`'s
    ///     `isFinal` callback since the commentator may have paused without
    ///     terminating punctuation.
    mutating func ingest(cumulative: String, forceFinal: Bool) -> [String] {
        let candidates = Self.scanSentences(in: cumulative, forceFinal: forceFinal)
        var newlyEmitted: [String] = []
        for sentence in candidates {
            let key = Self.canonical(sentence)
            if key.isEmpty { continue }
            if emitted.contains(key) { continue }
            emitted.insert(key)
            newlyEmitted.append(sentence)
        }
        return newlyEmitted
    }

    /// Mark every sentence in `cumulative` as already-emitted without
    /// returning it. Used when the mic captures our own TTS — STT transcribes
    /// the echo, but we don't want those sentences to hit Gemma. After the
    /// next real partial arrives, only genuinely new sentences emit.
    mutating func suppress(cumulative: String) {
        let candidates = Self.scanSentences(in: cumulative, forceFinal: true)
        for sentence in candidates {
            let key = Self.canonical(sentence)
            if !key.isEmpty { emitted.insert(key) }
        }
    }

    // MARK: - Internals

    /// Break `text` on sentence-ending punctuation (`.`, `!`, `?`) followed by
    /// whitespace or end-of-string. If `forceFinal`, any trailing non-empty
    /// buffer is also returned.
    ///
    /// Preserves punctuation in the returned strings — the canonicalizer
    /// strips it for dedup, but the raw sentence keeps it for display.
    static func scanSentences(in text: String, forceFinal: Bool) -> [String] {
        var out: [String] = []
        var buffer = ""
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            buffer.append(ch)
            if ch == "." || ch == "!" || ch == "?" {
                // Consume any trailing punctuation run ("?!", "...").
                while i + 1 < chars.count, ["!", "?", "."].contains(chars[i + 1]) {
                    i += 1
                    buffer.append(chars[i])
                }
                let next = i + 1 < chars.count ? chars[i + 1] : nil
                let isBoundary = next == nil || next!.isWhitespace
                if isBoundary {
                    let sentence = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                    if sentence.count > 1 { out.append(sentence) }
                    buffer = ""
                }
            }
            i += 1
        }
        if forceFinal {
            let tail = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if tail.count > 1 { out.append(tail) }
        }
        return out
    }

    /// Characters stripped before hashing. STT commonly adds/removes exactly
    /// these ("yeah, I'm" vs "yeah I'm"), so two sentences differing only in
    /// light punctuation must dedupe. Apostrophes stay — "don't" and "dont"
    /// shouldn't be treated as the same word at this level.
    private static let stripChars: Set<Character> = [",", ".", "!", "?", ";", ":", "\"", "—", "–"]

    /// Lowercase, drop light punctuation, collapse runs of whitespace. Two
    /// sentences with the same semantic content hash to the same key even
    /// when STT rewrites their surface form.
    static func canonical(_ s: String) -> String {
        var out = ""
        var lastWasSpace = false
        for raw in s.lowercased() {
            if stripChars.contains(raw) { continue }
            if raw.isWhitespace {
                if !lastWasSpace && !out.isEmpty { out.append(" ") }
                lastWasSpace = true
            } else {
                out.append(raw)
                lastWasSpace = false
            }
        }
        if out.hasSuffix(" ") { out.removeLast() }
        return out
    }
}

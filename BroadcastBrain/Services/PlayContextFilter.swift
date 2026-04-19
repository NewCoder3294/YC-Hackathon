import Foundation
import PlayByPlayKit

/// Deterministic play selection for LLM context windows.
///
/// Strategy (applied in priority order, deduplicated by play id):
///   1. Key events — always included (scoring, cards, subs, penalties, turnovers).
///   2. Recent tail — last `recentCount` plays, captures current game state.
///   3. Query-matched — when an utterance is available, plays mentioning the
///      same player/team/keyword are boosted in up to `maxQueryMatches`.
///
/// Output is sorted chronologically and capped at `maxTotal` plays.
struct PlayContextFilter {

    static let maxTotal: Int = 60
    static let recentCount: Int = 15
    static let maxKeyEvents: Int = 30
    static let maxQueryMatches: Int = 10

    /// Whisper tick path — no utterance available.
    static func filter(plays: [CompactPlay]) -> [CompactPlay] {
        filter(plays: plays, query: nil, compact: nil)
    }

    /// LivePane path — utterance available for query-aware boosting.
    static func filter(
        plays: [CompactPlay],
        query: String?,
        compact: CompactGame?
    ) -> [CompactPlay] {
        guard !plays.isEmpty else { return [] }
        if plays.count <= maxTotal { return plays }

        var selectedIds: [String] = []
        var seen = Set<String>()

        func add(_ play: CompactPlay) {
            guard !seen.contains(play.id) else { return }
            seen.insert(play.id)
            selectedIds.append(play.id)
        }

        // Pass 1: key events (chronological, capped)
        var keyCount = 0
        for play in plays {
            guard keyCount < maxKeyEvents else { break }
            if isKeyEvent(play) { add(play); keyCount += 1 }
        }

        // Pass 2: recent tail
        for play in plays.suffix(recentCount) { add(play) }

        // Pass 3: query matching
        if let query = query, !query.isEmpty, selectedIds.count < maxTotal {
            let tokens = queryTokens(from: query)
            if !tokens.isEmpty {
                let athletes = compact?.athletes ?? [:]
                var qCount = 0
                for play in plays {
                    guard qCount < maxQueryMatches, selectedIds.count < maxTotal else { break }
                    guard !seen.contains(play.id) else { continue }
                    if playMatchesTokens(play, tokens: tokens, athletes: athletes) {
                        add(play); qCount += 1
                    }
                }
            }
        }

        // Restore original chronological order
        let idIndex = Dictionary(uniqueKeysWithValues: plays.enumerated().map { ($1.id, $0) })
        return selectedIds
            .compactMap { id -> (Int, CompactPlay)? in
                guard let idx = idIndex[id] else { return nil }
                return (idx, plays[idx])
            }
            .sorted { $0.0 < $1.0 }
            .map { $0.1 }
    }

    // MARK: - Key event detection

    static func isKeyEvent(_ play: CompactPlay) -> Bool {
        if play.scoringPlay == true { return true }

        if let fields = play.sportFields {
            switch fields {
            case .soccer(let f):
                if f.redCard == true || f.yellowCard == true || f.penaltyKick == true
                    || f.ownGoal == true || f.substitution == true { return true }
            case .football(let f):
                if f.isTurnover == true { return true }
            case .hockey(let f):
                if f.isPenalty == true { return true }
            case .baseball(let f):
                if f.doublePlay == true || f.triplePlay == true
                    || (f.rbiCount ?? 0) > 0 { return true }
            case .basketball:
                break
            }
        }

        // Type-string fallback for sports not yet modelled in SportFields
        if let t = play.type?.lowercased() {
            let keywords = ["goal", "touchdown", "homerun", "home run", "penalty",
                            "red card", "yellow card", "turnover", "interception",
                            "fumble", "ejection", "substitution"]
            if keywords.contains(where: { t.contains($0) }) { return true }
        }

        return false
    }

    // MARK: - Query matching

    private static func queryTokens(from query: String) -> [String] {
        let stopwords: Set<String> = [
            "what", "when", "where", "which", "with", "from", "that", "this",
            "have", "been", "were", "they", "their", "about", "score", "play",
            "game", "last", "tell", "many", "much"
        ]
        return query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 && !stopwords.contains($0) }
    }

    private static func playMatchesTokens(
        _ play: CompactPlay,
        tokens: [String],
        athletes: [String: Athlete]
    ) -> Bool {
        let text = (play.text ?? "").lowercased()
        let names = (play.participants ?? [])
            .compactMap { $0.athleteId }
            .compactMap { athletes[$0]?.name.lowercased() }
        for token in tokens {
            if text.contains(token) { return true }
            if names.contains(where: { $0.contains(token) }) { return true }
        }
        return false
    }
}

import Foundation

/// Demo safety net. Substring-matches user text against scripted stat cards.
/// Used when `MOCK_MODE=1` env var is set, or when the real Gemma model fails to load.
final class MockResponder: CactusService {

    private let scripted: [(key: String, json: String)] = [
        ("ascends", """
         {"player":"Lionel Messi","stat_value":"108' ET goal","context_line":"5th & final World Cup — closes the circle","source":"Sportradar","confidence":"high"}
         """),
        ("messi penalty", """
         {"player":"Lionel Messi","stat_value":"23' PK","context_line":"Opens the final from the spot","source":"Sportradar","confidence":"high"}
         """),
        ("penalty", """
         {"player":"Lionel Messi","stat_value":"23' PK","context_line":"Opens the final from the spot","source":"Sportradar","confidence":"high"}
         """),
        ("mbappe", """
         {"player":"Kylian Mbappé","stat_value":"80' + 81' brace","context_line":"Fastest two-minute two-goal brace in a WC Final ever","source":"Sportradar","confidence":"high"}
         """),
        ("mbappé", """
         {"player":"Kylian Mbappé","stat_value":"80' + 81' brace","context_line":"Fastest two-minute two-goal brace in a WC Final ever","source":"Sportradar","confidence":"high"}
         """),
        ("di maria", """
         {"player":"Ángel Di María","stat_value":"36' finish","context_line":"Bookends a clinical Argentina move","source":"Sportradar","confidence":"high"}
         """),
        ("di maría", """
         {"player":"Ángel Di María","stat_value":"36' finish","context_line":"Bookends a clinical Argentina move","source":"Sportradar","confidence":"high"}
         """),
        ("messi", """
         {"player":"Lionel Messi","stat_value":"7 goals this WC","context_line":"Closes out the tournament as top Argentina scorer","source":"Sportradar","confidence":"high"}
         """),
    ]

    /// Research Q&A scripted answers (different keyspace to keep responses distinct)
    private let researchAnswers: [(key: String, answer: String)] = [
        ("mbappe", "Mbappé has 12 career World Cup goals — 4 in 2018, 8 in 2022. His 2022 hat-trick in the Final was the first since Geoff Hurst in 1966."),
        ("mbappé", "Mbappé has 12 career World Cup goals — 4 in 2018, 8 in 2022. His 2022 hat-trick in the Final was the first since Geoff Hurst in 1966."),
        ("messi", "Messi scored 13 career World Cup goals across five tournaments — 1 in 2006, 4 in 2014, 1 in 2018, 7 in 2022. 2022 was his final WC and he lifted the trophy in Lusail."),
        ("di maria", "Di María scored Argentina's second goal at 36' and assisted Messi's opening penalty. His first goal in a World Cup Final."),
        ("peter drury", "Peter Drury called the 2022 Final for ITV. His line 'Lionel Messi ascends to football heaven' is the most-viewed broadcast moment of the match."),
        ("lusail", "Lusail Stadium, Qatar. Capacity 88,966. Hosted the 2022 Final on 18 December 2022."),
    ]

    private let noDataJson = """
    {"no_verified_data":true,"context_line":"No verified data on that"}
    """

    func complete(system: String, user: String) async throws -> String {
        try await Task.sleep(nanoseconds: 350_000_000) // fake ~350ms inference

        let lower = user.lowercased()

        // If the system prompt looks like a research Q&A, return a prose answer.
        if system.lowercased().contains("research assistant") || system.lowercased().contains("q&a") {
            for (key, answer) in researchAnswers where lower.contains(key) {
                return answer
            }
            return "I don't have verified data on that."
        }

        // Route live-stream inputs by intent — this is the lightweight equivalent
        // of Cactus routing. Queries become whisper answers; non-queries are
        // broadcast moments that get a stat card.
        if Self.isQuery(lower) {
            for (key, answer) in researchAnswers where lower.contains(key) {
                return Self.whisperJson(player: Self.extractPlayer(from: lower) ?? "Whisper", answer: answer)
            }
            return Self.whisperJson(player: "Whisper", answer: "I don't have verified data on that.")
        }

        // Broadcast moment: return a stat card.
        for (key, json) in scripted where lower.contains(key) {
            return json
        }
        return noDataJson
    }

    /// Heuristic router — mirrors the `query_complexity` field Gemma would emit.
    /// If the transcript looks like a question, route to whisper. Otherwise stat.
    private static func isQuery(_ lower: String) -> Bool {
        if lower.contains("?") { return true }
        let openers = ["how ", "what ", "what's", "whats", "when ", "why ", "where ",
                       "who ", "tell me", "compare ", "explain ", "which "]
        for o in openers {
            if lower.hasPrefix(o) || lower.contains(" \(o)") { return true }
        }
        return false
    }

    private static func extractPlayer(from lower: String) -> String? {
        if lower.contains("mbappé") || lower.contains("mbappe") { return "Kylian Mbappé" }
        if lower.contains("messi") { return "Lionel Messi" }
        if lower.contains("di maría") || lower.contains("di maria") { return "Ángel Di María" }
        if lower.contains("martínez") || lower.contains("martinez") { return "Emiliano Martínez" }
        return nil
    }

    private static func whisperJson(player: String, answer: String) -> String {
        let escaped = answer.replacingOccurrences(of: "\"", with: "\\\"")
        return #"{"type":"whisper","player":"\#(player)","answer":"\#(escaped)","source":"Sportradar"}"#
    }
}

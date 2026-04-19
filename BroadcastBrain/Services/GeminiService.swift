import Foundation

enum GeminiError: LocalizedError {
    case missingKey(String)
    case badResponse(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .missingKey(let path):
            return "No Gemini API key. Save it to \(path)"
        case .badResponse(let s): return "Gemini error: \(s)"
        case .empty:              return "Gemini returned an empty response."
        }
    }
}

enum GeminiService {

    private static let model = "gemini-2.5-flash"

    private static var keyPath: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BroadcastBrain/gemini_key.txt")
    }

    static func apiKey() -> String? {
        guard let data = try? Data(contentsOf: keyPath),
              let raw  = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func synthesizeNews(headlines: [NewsItem], matchTitle: String?, playerNames: [String], userCurated: Bool) async throws -> String {
        guard let key = apiKey() else { throw GeminiError.missingKey(keyPath.path) }

        let headlineList = headlines.prefix(80).enumerated().map { idx, h in
            "\(idx + 1). [\(h.leagueLabel)] \(h.headline)\(h.description.isEmpty ? "" : " — \(h.description)")"
        }.joined(separator: "\n")

        let systemInstruction: String
        let userPrompt: String

        if userCurated {
            // User hand-picked these — synthesize them on their own merits,
            // ignore the loaded match context entirely.
            systemInstruction = """
            You are a broadcast prep assistant. The broadcaster hand-picked these headlines. Produce at least one bullet point per headline — never skip one, never say "no relevant information".
            Group bullets under these headings where they fit (omit truly empty ones):
            INJURIES & AVAILABILITY
            FORM & RECENT RESULTS
            STORYLINES & RIVALRY
            WILDCARDS
            Each bullet: 1–2 sentences summarizing what a commentator would want to say about that headline. Plain text only, no markdown syntax. Under 400 words total.
            """
            userPrompt = "Selected headlines:\n\(headlineList)"
        } else {
            let matchLine  = matchTitle.map { "Match: \($0)" } ?? "No specific match loaded."
            let playerLine = playerNames.isEmpty ? "" : "Players on the match roster: \(playerNames.prefix(20).joined(separator: ", "))"
            systemInstruction = """
            You are a broadcast prep assistant. From the headlines, produce a tight set of talking points for a live commentator.
            Prefer items relevant to the loaded match and its players, but still surface broader league context when nothing ties directly — never refuse with "no relevant information".
            Group findings under these headings (omit any that truly have no content):
            INJURIES & AVAILABILITY
            FORM & RECENT RESULTS
            STORYLINES & RIVALRY
            WILDCARDS
            Use short bullet points (1–2 sentences each). Keep the full response under 300 words. Plain text only, no markdown syntax.
            """
            userPrompt = """
            \(matchLine)
            \(playerLine)

            Headlines:
            \(headlineList)
            """
        }

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": systemInstruction]]],
            "contents": [["role": "user", "parts": [["text": userPrompt]]]],
            "generationConfig": ["temperature": 0.4, "maxOutputTokens": 1024],
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var req = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw GeminiError.badResponse("no response") }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "status \(http.statusCode)"
            throw GeminiError.badResponse(msg)
        }

        guard let json       = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content    = candidates.first?["content"] as? [String: Any],
              let parts      = content["parts"] as? [[String: Any]],
              let text       = parts.first?["text"] as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw GeminiError.empty }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

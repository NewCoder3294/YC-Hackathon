import Foundation

struct Session: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    var title: String
    var transcript: String
    var notes: String
    var statCards: [StatCard]
    var researchMessages: [ChatMessage]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String,
        transcript: String = "",
        notes: String = "",
        statCards: [StatCard] = [],
        researchMessages: [ChatMessage] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.transcript = transcript
        self.notes = notes
        self.statCards = statCards
        self.researchMessages = researchMessages
    }
}

enum StatCardKind: String, Codable, Equatable {
    case stat       // autonomous broadcast moment — hero stat, context line
    case whisper    // commentator-initiated query — prose answer
}

struct StatCard: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    var kind: StatCardKind
    let player: String
    let statValue: String
    let contextLine: String
    let source: String
    let rawTranscript: String
    let latencyMs: Int
    /// Whisper answer prose. Non-nil only when `kind == .whisper`.
    let answer: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: StatCardKind = .stat,
        player: String,
        statValue: String = "",
        contextLine: String = "",
        source: String = "Sportradar",
        rawTranscript: String,
        latencyMs: Int,
        answer: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.player = player
        self.statValue = statValue
        self.contextLine = contextLine
        self.source = source
        self.rawTranscript = rawTranscript
        self.latencyMs = latencyMs
        self.answer = answer
    }

    // Old sessions on disk won't have kind/answer. Decode with defaults.
    enum CodingKeys: String, CodingKey {
        case id, timestamp, kind, player, statValue, contextLine, source, rawTranscript, latencyMs, answer
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        kind = try c.decodeIfPresent(StatCardKind.self, forKey: .kind) ?? .stat
        player = try c.decode(String.self, forKey: .player)
        statValue = try c.decode(String.self, forKey: .statValue)
        contextLine = try c.decode(String.self, forKey: .contextLine)
        source = try c.decode(String.self, forKey: .source)
        rawTranscript = try c.decode(String.self, forKey: .rawTranscript)
        latencyMs = try c.decode(Int.self, forKey: .latencyMs)
        answer = try c.decodeIfPresent(String.self, forKey: .answer)
    }
}

enum Role: String, Codable, Equatable {
    case user
    case assistant
}

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let role: Role
    let content: String
    let grounded: Bool

    init(id: UUID = UUID(), role: Role, content: String, grounded: Bool) {
        self.id = id
        self.role = role
        self.content = content
        self.grounded = grounded
    }
}

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

struct StatCard: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let player: String
    let statValue: String
    let contextLine: String
    let source: String
    let rawTranscript: String
    let latencyMs: Int

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        player: String,
        statValue: String,
        contextLine: String,
        source: String = "Sportradar",
        rawTranscript: String,
        latencyMs: Int
    ) {
        self.id = id
        self.timestamp = timestamp
        self.player = player
        self.statValue = statValue
        self.contextLine = contextLine
        self.source = source
        self.rawTranscript = rawTranscript
        self.latencyMs = latencyMs
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

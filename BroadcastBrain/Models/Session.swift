import Foundation

enum Sport: String, Codable, CaseIterable, Identifiable {
    case soccer, basketball, baseball, americanFootball, hockey, cricket, rugby, tennis, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .soccer: return "Soccer"
        case .basketball: return "Basketball"
        case .baseball: return "Baseball"
        case .americanFootball: return "Football"
        case .hockey: return "Hockey"
        case .cricket: return "Cricket"
        case .rugby: return "Rugby"
        case .tennis: return "Tennis"
        case .other: return "Other"
        }
    }

    /// SF Symbol used in the live status bar. Cricket and rugby fall back to
    /// `sportscourt.fill` — dedicated symbols don't ship on macOS 14.
    var symbolName: String {
        switch self {
        case .soccer:            return "soccerball"
        case .basketball:        return "basketball.fill"
        case .baseball:          return "baseball.fill"
        case .americanFootball:  return "football.fill"
        case .hockey:            return "hockey.puck.fill"
        case .tennis:            return "tennisball.fill"
        case .cricket, .rugby:   return "sportscourt.fill"
        case .other:             return "sportscourt.fill"
        }
    }
}

struct Match: Codable, Equatable {
    var sport: Sport
    var homeTeam: String
    var awayTeam: String
    var tournament: String
    var venue: String
    var matchDate: Date?
    /// PlayByPlayKit `League.key` (e.g. "nba"). Nil when the commentator did
    /// not pick a live ESPN feed — the whisper engine still runs but has no
    /// plays context.
    var leagueKey: String?
    /// ESPN `Game.id` for the selected live game. Nil when no feed selected.
    var gameId: String?

    /// "Home vs Away · Tournament · Venue"
    var title: String {
        var pieces: [String] = []
        let matchup = "\(homeTeam) vs \(awayTeam)"
        pieces.append(matchup)
        if !tournament.isEmpty { pieces.append(tournament) }
        if !venue.isEmpty { pieces.append(venue) }
        return pieces.joined(separator: " · ")
    }

    static let sampleArgFra2022 = Match(
        sport: .soccer,
        homeTeam: "Argentina",
        awayTeam: "France",
        tournament: "2022 WC Final",
        venue: "Lusail Stadium",
        matchDate: nil,
        leagueKey: nil,
        gameId: nil
    )

    enum CodingKeys: String, CodingKey {
        case sport, homeTeam, awayTeam, tournament, venue, matchDate, leagueKey, gameId
    }

    init(
        sport: Sport,
        homeTeam: String,
        awayTeam: String,
        tournament: String,
        venue: String,
        matchDate: Date?,
        leagueKey: String? = nil,
        gameId: String? = nil
    ) {
        self.sport = sport
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.tournament = tournament
        self.venue = venue
        self.matchDate = matchDate
        self.leagueKey = leagueKey
        self.gameId = gameId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sport = try c.decode(Sport.self, forKey: .sport)
        homeTeam = try c.decode(String.self, forKey: .homeTeam)
        awayTeam = try c.decode(String.self, forKey: .awayTeam)
        tournament = try c.decode(String.self, forKey: .tournament)
        venue = try c.decode(String.self, forKey: .venue)
        matchDate = try c.decodeIfPresent(Date.self, forKey: .matchDate)
        leagueKey = try c.decodeIfPresent(String.self, forKey: .leagueKey)
        gameId = try c.decodeIfPresent(String.self, forKey: .gameId)
    }
}

struct Session: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    var title: String
    var match: Match?           // optional for legacy sessions on disk
    var transcript: String
    var notes: String
    var statCards: [StatCard]
    var researchMessages: [ChatMessage]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String,
        match: Match? = nil,
        transcript: String = "",
        notes: String = "",
        statCards: [StatCard] = [],
        researchMessages: [ChatMessage] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.match = match
        self.transcript = transcript
        self.notes = notes
        self.statCards = statCards
        self.researchMessages = researchMessages
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, title, match, transcript, notes, statCards, researchMessages
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        title = try c.decode(String.self, forKey: .title)
        match = try c.decodeIfPresent(Match.self, forKey: .match)
        transcript = try c.decode(String.self, forKey: .transcript)
        notes = try c.decode(String.self, forKey: .notes)
        statCards = try c.decode([StatCard].self, forKey: .statCards)
        researchMessages = try c.decode([ChatMessage].self, forKey: .researchMessages)
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

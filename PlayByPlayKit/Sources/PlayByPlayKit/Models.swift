import Foundation

public struct Game: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let shortName: String
    public let status: String
    public let statusDetail: String
    public let homeTeam: String
    public let awayTeam: String
    public let homeScore: String
    public let awayScore: String
    public let period: String
    public let homeTeamId: String?
    public let awayTeamId: String?
    public let homeTeamAbbr: String?
    public let awayTeamAbbr: String?
}

public struct Athlete: Hashable, Sendable, Codable {
    public let name: String
    public let jersey: String?
    public let position: String?
}

public struct CompactParticipant: Hashable, Sendable, Codable {
    public let athleteId: String?
    public let type: String?
    public let order: Int?
}

public struct LeagueRef: Hashable, Sendable, Codable {
    public let key: String
    public let sport: String
    public let league: String
}

public struct GameSummary: Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let shortName: String
    public let status: String
    public let statusDetail: String
    public let awayTeam: String
    public let homeTeam: String
    public let awayScore: String
    public let homeScore: String
}

public struct TeamRef: Hashable, Sendable, Codable {
    public let name: String?
    public let abbreviation: String?
}

public struct CompactPlay: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public var seq: String?
    public var type: String?
    public var text: String?
    public var awayScore: Int?
    public var homeScore: Int?
    public var clock: String?
    public var scoringPlay: Bool?
    public var scoreValue: Int?
    public var wallclock: String?
    public var teamId: String?
    public var participants: [CompactParticipant]?
    public var period: PeriodInfo?
    public var sportFields: SportFields?
}

public struct PeriodInfo: Hashable, Sendable, Codable {
    public let number: Int
    public let type: String?
    public let displayValue: String?
}

public struct CompactPeriod: Hashable, Sendable, Codable {
    public let number: Int
    public let type: String?
    public let displayValue: String?
    public let plays: [CompactPlay]
}

public struct CompactGame: Hashable, Sendable, Codable {
    public let league: LeagueRef
    public let game: GameSummary
    public let totalPlays: Int
    public let athletes: [String: Athlete]
    public let teams: [String: TeamRef]
    public let periods: [CompactPeriod]
}

public struct PlayDelta: Sendable {
    public let newPlays: [CompactPlay]
    public let state: CompactGame
}

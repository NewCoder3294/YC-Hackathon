import Foundation

public struct BaseballFields: Hashable, Sendable, Codable {
    public var pitchCoordinate: Coordinate?
    public var pitchType: String?
    public var pitchVelocity: Double?
    public var hitCoordinate: Coordinate?
    public var trajectory: String?
    public var atBatId: String?
    public var batOrder: Int?
    public var atBatPitchNumber: Int?
    public var bats: String?
    public var pitches: String?
    public var pitchCount: PitchCount?
    public var outs: Int?
    public var rbiCount: Int?
    public var awayHits: Int?
    public var homeHits: Int?
    public var awayErrors: Int?
    public var homeErrors: Int?
    public var doublePlay: Bool?
    public var triplePlay: Bool?
    public var summaryType: String?
}

public struct BasketballFields: Hashable, Sendable, Codable {
    public var coordinate: Coordinate?
    public var pointsAttempted: Int?
    public var shootingPlay: Bool?
}

public struct FootballFields: Hashable, Sendable, Codable {
    public var start: DriveMarker?
    public var end: DriveMarker?
    public var statYardage: Int?
    public var isTurnover: Bool?
    public var teamParticipants: [TeamParticipant]?
}

public struct HockeyFields: Hashable, Sendable, Codable {
    public var strength: String?
    public var isPenalty: Bool?
    public var shootingPlay: Bool?
}

public struct SoccerFields: Hashable, Sendable, Codable {
    public var redCard: Bool?
    public var yellowCard: Bool?
    public var penaltyKick: Bool?
    public var ownGoal: Bool?
    public var shootout: Bool?
    public var substitution: Bool?
    public var addedClock: Double?
    public var fieldPosition: FieldPosition?
    public var fieldPosition2: FieldPosition?
    public var goalPosition: GoalPosition?
}

public enum SportFields: Hashable, Sendable {
    case baseball(BaseballFields)
    case basketball(BasketballFields)
    case football(FootballFields)
    case hockey(HockeyFields)
    case soccer(SoccerFields)
}

extension SportFields: Codable {
    private enum CodingKeys: String, CodingKey {
        case sport
        case data
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .baseball(let v):
            try c.encode("baseball", forKey: .sport)
            try c.encode(v, forKey: .data)
        case .basketball(let v):
            try c.encode("basketball", forKey: .sport)
            try c.encode(v, forKey: .data)
        case .football(let v):
            try c.encode("football", forKey: .sport)
            try c.encode(v, forKey: .data)
        case .hockey(let v):
            try c.encode("hockey", forKey: .sport)
            try c.encode(v, forKey: .data)
        case .soccer(let v):
            try c.encode("soccer", forKey: .sport)
            try c.encode(v, forKey: .data)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let sport = try c.decode(String.self, forKey: .sport)
        switch sport {
        case "baseball":
            self = .baseball(try c.decode(BaseballFields.self, forKey: .data))
        case "basketball":
            self = .basketball(try c.decode(BasketballFields.self, forKey: .data))
        case "football":
            self = .football(try c.decode(FootballFields.self, forKey: .data))
        case "hockey":
            self = .hockey(try c.decode(HockeyFields.self, forKey: .data))
        case "soccer":
            self = .soccer(try c.decode(SoccerFields.self, forKey: .data))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .sport,
                in: c,
                debugDescription: "Unknown sport: \(sport)"
            )
        }
    }
}

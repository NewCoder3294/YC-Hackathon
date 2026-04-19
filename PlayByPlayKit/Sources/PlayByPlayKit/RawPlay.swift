import Foundation

struct TextHolder: Decodable {
    let text: String?
}

struct DisplayValueHolder: Decodable {
    let displayValue: String?
}

struct RefHolder: Decodable {
    let ref: String?
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
    }
}

struct AbbrHolder: Decodable {
    let abbreviation: String?
    let displayName: String?
}

struct ValueHolder: Decodable {
    let value: Double?
}

struct RawCoordinate: Decodable {
    let x: Double?
    let y: Double?
}

struct RawPeriod: Decodable {
    let number: Int?
    let type: String?
    let displayValue: String?
}

struct RawAthleteRef: Decodable {
    let ref: String?
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
    }
}

struct RawParticipant: Decodable {
    let athlete: RawAthleteRef?
    let type: String?
    let order: Int?
}

struct RawPitchCount: Decodable {
    let balls: Int?
    let strikes: Int?
}

struct RawDriveMarker: Decodable {
    let down: Int?
    let distance: Int?
    let yardLine: Int?
    let yardsToEndzone: Int?
    let shortDownDistanceText: String?
    let possessionText: String?
    let team: RefHolder?
}

struct RawTeamParticipant: Decodable {
    let id: String?
    let team: RefHolder?
    let order: Int?
    let type: String?
}

struct RawPlay: Decodable {
    // Core
    let id: String
    let sequenceNumber: String?
    let type: TextHolder?
    let text: String?
    let awayScore: Int?
    let homeScore: Int?
    let clock: DisplayValueHolder?
    let wallclock: String?
    let scoringPlay: Bool?
    let scoreValue: Int?
    let team: RefHolder?
    let period: RawPeriod?
    let participants: [RawParticipant]?

    // Baseball
    let pitchCoordinate: RawCoordinate?
    let pitchType: TextHolder?
    let pitchVelocity: Double?
    let hitCoordinate: RawCoordinate?
    let trajectory: String?
    let atBatId: String?
    let batOrder: Int?
    let atBatPitchNumber: Int?
    let bats: AbbrHolder?
    let pitches: AbbrHolder?
    let pitchCount: RawPitchCount?
    let outs: Int?
    let rbiCount: Int?
    let awayHits: Int?
    let homeHits: Int?
    let awayErrors: Int?
    let homeErrors: Int?
    let doublePlay: Bool?
    let triplePlay: Bool?
    let summaryType: String?

    // Basketball
    let coordinate: RawCoordinate?
    let pointsAttempted: Int?
    let shootingPlay: Bool?

    // Football
    let start: RawDriveMarker?
    let end: RawDriveMarker?
    let statYardage: Int?
    let isTurnover: Bool?
    let teamParticipants: [RawTeamParticipant]?

    // Hockey
    let strength: TextHolder?
    let isPenalty: Bool?

    // Soccer
    let redCard: Bool?
    let yellowCard: Bool?
    let penaltyKick: Bool?
    let ownGoal: Bool?
    let shootout: Bool?
    let substitution: Bool?
    let addedClock: ValueHolder?
    let fieldPositionX: Double?
    let fieldPositionY: Double?
    let fieldPosition2X: Double?
    let fieldPosition2Y: Double?
    let goalPositionX: Double?
    let goalPositionY: Double?
    let goalPositionZ: Double?
}

struct PlayByPlayResponse: Decodable {
    let items: [RawPlay]?
}

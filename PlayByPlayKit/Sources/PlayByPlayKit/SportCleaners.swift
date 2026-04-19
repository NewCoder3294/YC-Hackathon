import Foundation

/// Sentinel values ESPN uses to indicate "no court position" on basketball plays.
private let basketballSentinelX: Double = -214748340
private let basketballSentinelY: Double = -214748365

enum SportCleaners {
    static func cleanBaseball(_ raw: RawPlay) -> BaseballFields {
        var f = BaseballFields()
        if let c = raw.pitchCoordinate { f.pitchCoordinate = Coordinate(x: c.x, y: c.y) }
        if let t = raw.pitchType?.text { f.pitchType = t }
        f.pitchVelocity = raw.pitchVelocity
        if let c = raw.hitCoordinate { f.hitCoordinate = Coordinate(x: c.x, y: c.y) }
        f.trajectory = raw.trajectory
        f.atBatId = raw.atBatId
        f.batOrder = raw.batOrder
        f.atBatPitchNumber = raw.atBatPitchNumber
        f.bats = raw.bats?.abbreviation
        f.pitches = raw.pitches?.abbreviation
        if let pc = raw.pitchCount {
            f.pitchCount = PitchCount(balls: pc.balls, strikes: pc.strikes)
        }
        f.outs = raw.outs
        f.rbiCount = raw.rbiCount
        f.awayHits = raw.awayHits
        f.homeHits = raw.homeHits
        f.awayErrors = raw.awayErrors
        f.homeErrors = raw.homeErrors
        f.doublePlay = raw.doublePlay
        f.triplePlay = raw.triplePlay
        f.summaryType = raw.summaryType
        return f
    }

    static func cleanBasketball(_ raw: RawPlay) -> BasketballFields {
        var f = BasketballFields()
        if let c = raw.coordinate, c.x != basketballSentinelX, c.y != basketballSentinelY {
            f.coordinate = Coordinate(x: c.x, y: c.y)
        }
        f.pointsAttempted = raw.pointsAttempted
        f.shootingPlay = raw.shootingPlay
        return f
    }

    static func cleanFootball(_ raw: RawPlay) -> FootballFields {
        var f = FootballFields()
        f.start = driveMarker(raw.start)
        f.end = driveMarker(raw.end)
        f.statYardage = raw.statYardage
        f.isTurnover = raw.isTurnover
        if let tps = raw.teamParticipants, !tps.isEmpty {
            f.teamParticipants = tps.map { tp in
                TeamParticipant(
                    teamId: tp.id ?? ESPNRef.extractId(from: tp.team?.ref),
                    order: tp.order,
                    type: tp.type
                )
            }
        }
        return f
    }

    static func cleanHockey(_ raw: RawPlay) -> HockeyFields {
        var f = HockeyFields()
        f.strength = raw.strength?.text
        f.isPenalty = raw.isPenalty
        f.shootingPlay = raw.shootingPlay
        return f
    }

    static func cleanSoccer(_ raw: RawPlay) -> SoccerFields {
        var f = SoccerFields()
        f.redCard = raw.redCard
        f.yellowCard = raw.yellowCard
        f.penaltyKick = raw.penaltyKick
        f.ownGoal = raw.ownGoal
        f.shootout = raw.shootout
        f.substitution = raw.substitution
        f.addedClock = raw.addedClock?.value
        if raw.fieldPositionX != nil || raw.fieldPositionY != nil {
            f.fieldPosition = FieldPosition(x: raw.fieldPositionX, y: raw.fieldPositionY)
        }
        if raw.fieldPosition2X != nil || raw.fieldPosition2Y != nil {
            f.fieldPosition2 = FieldPosition(x: raw.fieldPosition2X, y: raw.fieldPosition2Y)
        }
        if raw.goalPositionX != nil || raw.goalPositionY != nil || raw.goalPositionZ != nil {
            f.goalPosition = GoalPosition(x: raw.goalPositionX, y: raw.goalPositionY, z: raw.goalPositionZ)
        }
        return f
    }

    private static func driveMarker(_ m: RawDriveMarker?) -> DriveMarker? {
        guard let m else { return nil }
        let hasAny = m.down != nil || m.distance != nil || m.yardLine != nil || m.yardsToEndzone != nil || m.shortDownDistanceText != nil || m.possessionText != nil || m.team != nil
        guard hasAny else { return nil }
        return DriveMarker(
            down: m.down,
            distance: m.distance,
            yardLine: m.yardLine,
            yardsToEndzone: m.yardsToEndzone,
            downDistance: m.shortDownDistanceText,
            possession: m.possessionText,
            teamId: ESPNRef.extractId(from: m.team?.ref)
        )
    }
}

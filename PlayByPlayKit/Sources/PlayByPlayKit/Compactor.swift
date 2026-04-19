import Foundation

enum Compactor {
    static func compactPlay(
        _ raw: RawPlay,
        sport: String,
        athletes: inout [String: Athlete]
    ) -> CompactPlay {
        var participants: [CompactParticipant]?
        if let parts = raw.participants, !parts.isEmpty {
            participants = parts.map { p in
                let id = ESPNRef.extractId(from: p.athlete?.ref)
                return CompactParticipant(athleteId: id, type: p.type, order: p.order)
            }
        }

        var sportFields: SportFields?
        switch sport {
        case "baseball":
            sportFields = .baseball(SportCleaners.cleanBaseball(raw))
        case "basketball":
            sportFields = .basketball(SportCleaners.cleanBasketball(raw))
        case "football":
            sportFields = .football(SportCleaners.cleanFootball(raw))
        case "hockey":
            sportFields = .hockey(SportCleaners.cleanHockey(raw))
        case "soccer":
            sportFields = .soccer(SportCleaners.cleanSoccer(raw))
        default:
            sportFields = nil
        }

        let periodInfo: PeriodInfo? = raw.period.map { p in
            PeriodInfo(number: p.number ?? 0, type: p.type, displayValue: p.displayValue)
        }

        return CompactPlay(
            id: raw.id,
            seq: raw.sequenceNumber,
            type: raw.type?.text,
            text: raw.text,
            awayScore: raw.awayScore,
            homeScore: raw.homeScore,
            clock: raw.clock?.displayValue,
            scoringPlay: raw.scoringPlay,
            scoreValue: raw.scoreValue,
            wallclock: raw.wallclock,
            teamId: ESPNRef.extractId(from: raw.team?.ref),
            participants: participants,
            period: periodInfo,
            sportFields: sportFields
        )
    }

    static func compactGame(
        league: League,
        game: Game,
        rawPlays: [RawPlay],
        athleteMap: [String: AthleteResponse]
    ) -> CompactGame {
        var athletes: [String: Athlete] = [:]
        var teams: [String: TeamRef] = [:]

        if let id = game.homeTeamId {
            teams[id] = TeamRef(name: game.homeTeam, abbreviation: game.homeTeamAbbr)
        }
        if let id = game.awayTeamId {
            teams[id] = TeamRef(name: game.awayTeam, abbreviation: game.awayTeamAbbr)
        }

        // Pre-populate athletes from resolved refs.
        for (ref, a) in athleteMap {
            let id = a.id ?? ESPNRef.extractId(from: ref)
            guard let id, let name = a.displayName ?? a.fullName else { continue }
            if athletes[id] == nil {
                athletes[id] = Athlete(
                    name: name,
                    jersey: a.jersey,
                    position: a.position?.abbreviation ?? a.position?.displayName
                )
            }
        }

        struct PeriodKey: Hashable {
            let number: Int
            let type: String
        }
        var orderedKeys: [PeriodKey] = []
        var byKey: [PeriodKey: (type: String?, displayValue: String?, plays: [CompactPlay])] = [:]

        for raw in rawPlays {
            let cp = compactPlay(raw, sport: league.sport, athletes: &athletes)
            let number = raw.period?.number ?? 0
            let typeStr = raw.period?.type ?? ""
            let key = PeriodKey(number: number, type: typeStr)
            if byKey[key] == nil {
                byKey[key] = (type: raw.period?.type, displayValue: raw.period?.displayValue, plays: [])
                orderedKeys.append(key)
            }
            byKey[key]!.plays.append(cp)
        }

        let periods = orderedKeys.map { key -> CompactPeriod in
            let v = byKey[key]!
            return CompactPeriod(number: key.number, type: v.type, displayValue: v.displayValue, plays: v.plays)
        }

        return CompactGame(
            league: LeagueRef(key: league.key, sport: league.sport, league: league.league),
            game: GameSummary(
                id: game.id,
                name: game.name,
                shortName: game.shortName,
                status: game.status,
                statusDetail: game.statusDetail,
                awayTeam: game.awayTeam,
                homeTeam: game.homeTeam,
                awayScore: game.awayScore,
                homeScore: game.homeScore
            ),
            totalPlays: rawPlays.count,
            athletes: athletes,
            teams: teams,
            periods: periods
        )
    }

    /// Returns the last play ID across all periods (walking back-to-front).
    static func lastCompactPlayId(_ game: CompactGame?) -> String? {
        guard let game else { return nil }
        for period in game.periods.reversed() {
            if let last = period.plays.last { return last.id }
        }
        return nil
    }

    /// Returns plays in `next` that appear after `lastId` in `next`'s own order.
    /// If `lastId` is nil (cold start), all plays are considered new.
    /// If `lastId` isn't found in `next`, all of `next`'s plays are considered new.
    static func diffNewPlays(prev: CompactGame?, next: CompactGame) -> [CompactPlay] {
        let allNext = next.periods.flatMap { $0.plays }
        guard let lastId = lastCompactPlayId(prev) else { return allNext }
        guard let idx = allNext.firstIndex(where: { $0.id == lastId }) else { return allNext }
        return Array(allNext[allNext.index(after: idx)...])
    }
}

import Foundation

struct ScoreboardResponse: Decodable {
    struct Event: Decodable {
        let id: String
        let name: String
        let shortName: String
        let competitions: [Competition]
    }

    struct Competition: Decodable {
        let competitors: [Competitor]
        let status: Status
    }

    struct Competitor: Decodable {
        let id: String
        let homeAway: String
        let team: Team
        let score: String?
    }

    struct Team: Decodable {
        let displayName: String
        let abbreviation: String?
    }

    struct Status: Decodable {
        let type: StatusType
    }

    struct StatusType: Decodable {
        let description: String
        let detail: String
    }

    let events: [Event]?
}

enum Scoreboard {
    static func toGames(_ response: ScoreboardResponse) -> [Game] {
        (response.events ?? []).compactMap { event in
            guard let comp = event.competitions.first,
                  let home = comp.competitors.first(where: { $0.homeAway == "home" }),
                  let away = comp.competitors.first(where: { $0.homeAway == "away" })
            else { return nil }

            return Game(
                id: event.id,
                name: event.name,
                shortName: event.shortName,
                status: comp.status.type.description,
                statusDetail: comp.status.type.detail,
                homeTeam: home.team.displayName,
                awayTeam: away.team.displayName,
                homeScore: home.score ?? "0",
                awayScore: away.score ?? "0",
                period: comp.status.type.detail,
                homeTeamId: home.id,
                awayTeamId: away.id,
                homeTeamAbbr: home.team.abbreviation,
                awayTeamAbbr: away.team.abbreviation
            )
        }
    }
}

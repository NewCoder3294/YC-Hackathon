import Foundation

public struct League: Hashable, Sendable, Codable {
    public let key: String
    public let sport: String
    public let league: String
    public let displayName: String

    public init(key: String, sport: String, league: String, displayName: String) {
        self.key = key
        self.sport = sport
        self.league = league
        self.displayName = displayName
    }
}

public extension League {
    static let all: [League] = [
        League(key: "mlb", sport: "baseball", league: "mlb", displayName: "MLB — Baseball"),
        League(key: "nba", sport: "basketball", league: "nba", displayName: "NBA — Basketball"),
        League(key: "wnba", sport: "basketball", league: "wnba", displayName: "WNBA — Basketball"),
        League(key: "ncaam", sport: "basketball", league: "mens-college-basketball", displayName: "NCAAM — College Basketball"),
        League(key: "ncaaw", sport: "basketball", league: "womens-college-basketball", displayName: "NCAAW — College Basketball"),
        League(key: "nfl", sport: "football", league: "nfl", displayName: "NFL — Football"),
        League(key: "ncaaf", sport: "football", league: "college-football", displayName: "NCAAF — College Football"),
        League(key: "nhl", sport: "hockey", league: "nhl", displayName: "NHL — Hockey"),
        League(key: "epl", sport: "soccer", league: "eng.1", displayName: "EPL — Soccer"),
        League(key: "laliga", sport: "soccer", league: "esp.1", displayName: "La Liga — Soccer"),
        League(key: "seriea", sport: "soccer", league: "ita.1", displayName: "Serie A — Soccer"),
        League(key: "bundesliga", sport: "soccer", league: "ger.1", displayName: "Bundesliga — Soccer"),
        League(key: "ligue1", sport: "soccer", league: "fra.1", displayName: "Ligue 1 — Soccer"),
        League(key: "ucl", sport: "soccer", league: "uefa.champions", displayName: "UEFA Champions League — Soccer"),
        League(key: "mls", sport: "soccer", league: "usa.1", displayName: "MLS — Soccer"),
    ]
}

enum ESPNEndpoints {
    static func scoreboardURL(_ l: League) -> URL {
        URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(l.sport)/\(l.league)/scoreboard")!
    }

    static func playByPlayURL(_ l: League, gameId: String, limit: Int = 1000) -> URL {
        URL(string: "https://sports.core.api.espn.com/v2/sports/\(l.sport)/leagues/\(l.league)/events/\(gameId)/competitions/\(gameId)/plays?limit=\(limit)")!
    }
}

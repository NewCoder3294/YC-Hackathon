#!/usr/bin/env swift
/**
 * FetchGame.swift — BroadcastBrain overnight game cache builder.
 *
 * WHAT THIS SCRIPT DOES:
 *   Run it the night before a game with a team name. It pulls everything the
 *   spotting board needs — next game details, both rosters, player stats,
 *   news headlines, and injury reports — then writes it all to
 *   assets/game_cache.json so the app works in airplane mode during the demo.
 *
 * HOW IT GETS THE DATA (no paid APIs, no API keys):
 *   Sport        │ API used
 *   ─────────────┼────────────────────────────────────────
 *   Soccer       │ ESPN unofficial (site.api.espn.com)
 *   Basketball   │ ESPN unofficial (site.api.espn.com)
 *   Baseball     │ MLB official   (statsapi.mlb.com)
 *   Hockey       │ NHL official   (api-web.nhle.com)
 *   News/injury  │ Google News RSS (news.google.com/rss)
 *
 * USAGE:
 *   swift src/data/FetchGame.swift "Manchester City"
 *   swift src/data/FetchGame.swift "Los Angeles Lakers"
 *   swift src/data/FetchGame.swift "New York Yankees"
 *   swift src/data/FetchGame.swift "Toronto Maple Leafs"
 *
 * OUTPUT:
 *   assets/game_cache.json
 */

import Foundation

// MARK: - Types

struct PlayerStats: Codable {
    var season: [String: String]
    var formLast5: [String: String]
    var vsOpponent: [String: String]
    enum CodingKeys: String, CodingKey {
        case season
        case formLast5  = "form_last_5"
        case vsOpponent = "vs_opponent"
    }
}

struct Player: Codable {
    var id: String
    var teamId: String
    var shirtNumber: Int
    var name: String
    var position: String
    var age: Int
    var stats: PlayerStats
    var storyline: String
    var matchupNote: String
    var topStats: [String]
    var status: PlayerStatus
    var newsHeadlines: [String]
    enum PlayerStatus: String, Codable { case fit, doubtful, injured, suspended }
    enum CodingKeys: String, CodingKey {
        case id, name, position, age, stats, storyline, status
        case teamId       = "team_id"
        case shirtNumber  = "shirt_number"
        case matchupNote  = "matchup_note"
        case topStats     = "top_stats"
        case newsHeadlines = "news_headlines"
    }
}

struct Team: Codable {
    var id: String
    var name: String
    var colorHex: String
    var record: [String: String]
    enum CodingKeys: String, CodingKey {
        case id, name, record
        case colorHex = "color_hex"
    }
}

struct MatchInfo: Codable {
    var id: String
    var homeTeam: String
    var awayTeam: String
    var competition: String
    var venue: String
    var kickoffISO: String
    enum CodingKeys: String, CodingKey {
        case id, competition, venue
        case homeTeam   = "home_team"
        case awayTeam   = "away_team"
        case kickoffISO = "kickoff_iso"
    }
}

struct TeamsPayload: Codable {
    var home: Team
    var away: Team
}

struct GameCache: Codable {
    var match: MatchInfo
    var teams: TeamsPayload
    var players: [Player]
    var storylines: [String]
    var source: String
    var generatedAt: String
    enum CodingKeys: String, CodingKey {
        case match, teams, players, storylines, source
        case generatedAt = "generated_at"
    }
}

struct GameInfo {
    var eventId: String
    var homeTeam: String
    var awayTeam: String
    var homeId: String
    var awayId: String
    var venue: String
    var dateISO: String
    var competition: String
}

struct RawPlayer {
    var id: String
    var name: String
    var number: Int?
    var position: String
    var age: Int?
}

typealias SportEntry = (sport: String, league: String, display: String)

// MARK: - Constants

let KNOWN_TEAMS: [String: SportEntry] = [
    // Soccer – Premier League
    "manchester city":      ("soccer", "eng.1", "Premier League"),
    "manchester united":    ("soccer", "eng.1", "Premier League"),
    "liverpool":            ("soccer", "eng.1", "Premier League"),
    "arsenal":              ("soccer", "eng.1", "Premier League"),
    "chelsea":              ("soccer", "eng.1", "Premier League"),
    "tottenham":            ("soccer", "eng.1", "Premier League"),
    "spurs":                ("soccer", "eng.1", "Premier League"),
    "newcastle":            ("soccer", "eng.1", "Premier League"),
    "aston villa":          ("soccer", "eng.1", "Premier League"),
    "west ham":             ("soccer", "eng.1", "Premier League"),
    "brighton":             ("soccer", "eng.1", "Premier League"),
    "everton":              ("soccer", "eng.1", "Premier League"),
    "fulham":               ("soccer", "eng.1", "Premier League"),
    "brentford":            ("soccer", "eng.1", "Premier League"),
    "nottingham forest":    ("soccer", "eng.1", "Premier League"),
    "wolves":               ("soccer", "eng.1", "Premier League"),
    "wolverhampton":        ("soccer", "eng.1", "Premier League"),
    "crystal palace":       ("soccer", "eng.1", "Premier League"),
    "leicester":            ("soccer", "eng.1", "Premier League"),
    "ipswich":              ("soccer", "eng.1", "Premier League"),
    "southampton":          ("soccer", "eng.1", "Premier League"),
    "leeds":                ("soccer", "eng.1", "Premier League"),
    // Soccer – La Liga
    "real madrid":          ("soccer", "esp.1", "La Liga"),
    "barcelona":            ("soccer", "esp.1", "La Liga"),
    "atletico madrid":      ("soccer", "esp.1", "La Liga"),
    "athletic bilbao":      ("soccer", "esp.1", "La Liga"),
    "real sociedad":        ("soccer", "esp.1", "La Liga"),
    "villarreal":           ("soccer", "esp.1", "La Liga"),
    "sevilla":              ("soccer", "esp.1", "La Liga"),
    "betis":                ("soccer", "esp.1", "La Liga"),
    // Soccer – Bundesliga
    "bayern munich":        ("soccer", "ger.1", "Bundesliga"),
    "borussia dortmund":    ("soccer", "ger.1", "Bundesliga"),
    "bayer leverkusen":     ("soccer", "ger.1", "Bundesliga"),
    "rb leipzig":           ("soccer", "ger.1", "Bundesliga"),
    "eintracht frankfurt":  ("soccer", "ger.1", "Bundesliga"),
    // Soccer – Serie A
    "juventus":             ("soccer", "ita.1", "Serie A"),
    "inter milan":          ("soccer", "ita.1", "Serie A"),
    "ac milan":             ("soccer", "ita.1", "Serie A"),
    "napoli":               ("soccer", "ita.1", "Serie A"),
    "roma":                 ("soccer", "ita.1", "Serie A"),
    "lazio":                ("soccer", "ita.1", "Serie A"),
    "atalanta":             ("soccer", "ita.1", "Serie A"),
    "fiorentina":           ("soccer", "ita.1", "Serie A"),
    // Soccer – Ligue 1
    "paris saint-germain":  ("soccer", "fra.1", "Ligue 1"),
    "psg":                  ("soccer", "fra.1", "Ligue 1"),
    "monaco":               ("soccer", "fra.1", "Ligue 1"),
    "marseille":            ("soccer", "fra.1", "Ligue 1"),
    "lyon":                 ("soccer", "fra.1", "Ligue 1"),
    "nice":                 ("soccer", "fra.1", "Ligue 1"),
    "lille":                ("soccer", "fra.1", "Ligue 1"),
    // Soccer – MLS
    "inter miami":          ("soccer", "usa.1", "MLS"),
    "la galaxy":            ("soccer", "usa.1", "MLS"),
    "lafc":                 ("soccer", "usa.1", "MLS"),
    "seattle sounders":     ("soccer", "usa.1", "MLS"),
    "portland timbers":     ("soccer", "usa.1", "MLS"),
    "new york city":        ("soccer", "usa.1", "MLS"),
    "new york red bulls":   ("soccer", "usa.1", "MLS"),
    "atlanta united":       ("soccer", "usa.1", "MLS"),
    // NBA
    "los angeles lakers":    ("basketball", "nba", "NBA"),
    "lakers":                ("basketball", "nba", "NBA"),
    "golden state warriors": ("basketball", "nba", "NBA"),
    "warriors":              ("basketball", "nba", "NBA"),
    "boston celtics":        ("basketball", "nba", "NBA"),
    "celtics":               ("basketball", "nba", "NBA"),
    "miami heat":            ("basketball", "nba", "NBA"),
    "chicago bulls":         ("basketball", "nba", "NBA"),
    "brooklyn nets":         ("basketball", "nba", "NBA"),
    "new york knicks":       ("basketball", "nba", "NBA"),
    "knicks":                ("basketball", "nba", "NBA"),
    "dallas mavericks":      ("basketball", "nba", "NBA"),
    "mavs":                  ("basketball", "nba", "NBA"),
    "milwaukee bucks":       ("basketball", "nba", "NBA"),
    "denver nuggets":        ("basketball", "nba", "NBA"),
    "phoenix suns":          ("basketball", "nba", "NBA"),
    "philadelphia 76ers":    ("basketball", "nba", "NBA"),
    "cleveland cavaliers":   ("basketball", "nba", "NBA"),
    "oklahoma city thunder": ("basketball", "nba", "NBA"),
    "houston rockets":       ("basketball", "nba", "NBA"),
    "memphis grizzlies":     ("basketball", "nba", "NBA"),
    "sacramento kings":      ("basketball", "nba", "NBA"),
    "minnesota timberwolves":("basketball", "nba", "NBA"),
    "indiana pacers":        ("basketball", "nba", "NBA"),
    "new orleans pelicans":  ("basketball", "nba", "NBA"),
    "toronto raptors":       ("basketball", "nba", "NBA"),
    "atlanta hawks":         ("basketball", "nba", "NBA"),
    "orlando magic":         ("basketball", "nba", "NBA"),
    "washington wizards":    ("basketball", "nba", "NBA"),
    "detroit pistons":       ("basketball", "nba", "NBA"),
    "charlotte hornets":     ("basketball", "nba", "NBA"),
    "portland trail blazers":("basketball", "nba", "NBA"),
    "san antonio spurs":     ("basketball", "nba", "NBA"),
    "utah jazz":             ("basketball", "nba", "NBA"),
    // MLB
    "new york yankees":      ("baseball", "mlb", "MLB"),
    "yankees":               ("baseball", "mlb", "MLB"),
    "los angeles dodgers":   ("baseball", "mlb", "MLB"),
    "dodgers":               ("baseball", "mlb", "MLB"),
    "boston red sox":        ("baseball", "mlb", "MLB"),
    "red sox":               ("baseball", "mlb", "MLB"),
    "chicago cubs":          ("baseball", "mlb", "MLB"),
    "san francisco giants":  ("baseball", "mlb", "MLB"),
    "new york mets":         ("baseball", "mlb", "MLB"),
    "mets":                  ("baseball", "mlb", "MLB"),
    "houston astros":        ("baseball", "mlb", "MLB"),
    "astros":                ("baseball", "mlb", "MLB"),
    "atlanta braves":        ("baseball", "mlb", "MLB"),
    "braves":                ("baseball", "mlb", "MLB"),
    "philadelphia phillies": ("baseball", "mlb", "MLB"),
    "phillies":              ("baseball", "mlb", "MLB"),
    "st. louis cardinals":   ("baseball", "mlb", "MLB"),
    "cardinals":             ("baseball", "mlb", "MLB"),
    "seattle mariners":      ("baseball", "mlb", "MLB"),
    "mariners":              ("baseball", "mlb", "MLB"),
    "chicago white sox":     ("baseball", "mlb", "MLB"),
    "minnesota twins":       ("baseball", "mlb", "MLB"),
    "cleveland guardians":   ("baseball", "mlb", "MLB"),
    "miami marlins":         ("baseball", "mlb", "MLB"),
    "tampa bay rays":        ("baseball", "mlb", "MLB"),
    "toronto blue jays":     ("baseball", "mlb", "MLB"),
    "blue jays":             ("baseball", "mlb", "MLB"),
    "baltimore orioles":     ("baseball", "mlb", "MLB"),
    "orioles":               ("baseball", "mlb", "MLB"),
    "texas rangers":         ("baseball", "mlb", "MLB"),
    "kansas city royals":    ("baseball", "mlb", "MLB"),
    "royals":                ("baseball", "mlb", "MLB"),
    "oakland athletics":     ("baseball", "mlb", "MLB"),
    "athletics":             ("baseball", "mlb", "MLB"),
    "colorado rockies":      ("baseball", "mlb", "MLB"),
    "rockies":               ("baseball", "mlb", "MLB"),
    "san diego padres":      ("baseball", "mlb", "MLB"),
    "padres":                ("baseball", "mlb", "MLB"),
    "cincinnati reds":       ("baseball", "mlb", "MLB"),
    "pittsburgh pirates":    ("baseball", "mlb", "MLB"),
    "detroit tigers":        ("baseball", "mlb", "MLB"),
    "tigers":                ("baseball", "mlb", "MLB"),
    "arizona diamondbacks":  ("baseball", "mlb", "MLB"),
    "milwaukee brewers":     ("baseball", "mlb", "MLB"),
    "brewers":               ("baseball", "mlb", "MLB"),
    "washington nationals":  ("baseball", "mlb", "MLB"),
    "los angeles angels":    ("baseball", "mlb", "MLB"),
    "angels":                ("baseball", "mlb", "MLB"),
    // NHL
    "toronto maple leafs":   ("hockey", "nhl", "NHL"),
    "leafs":                 ("hockey", "nhl", "NHL"),
    "montreal canadiens":    ("hockey", "nhl", "NHL"),
    "canadiens":             ("hockey", "nhl", "NHL"),
    "boston bruins":         ("hockey", "nhl", "NHL"),
    "bruins":                ("hockey", "nhl", "NHL"),
    "new york rangers":      ("hockey", "nhl", "NHL"),
    "edmonton oilers":       ("hockey", "nhl", "NHL"),
    "oilers":                ("hockey", "nhl", "NHL"),
    "colorado avalanche":    ("hockey", "nhl", "NHL"),
    "avalanche":             ("hockey", "nhl", "NHL"),
    "tampa bay lightning":   ("hockey", "nhl", "NHL"),
    "lightning":             ("hockey", "nhl", "NHL"),
    "vegas golden knights":  ("hockey", "nhl", "NHL"),
    "golden knights":        ("hockey", "nhl", "NHL"),
    "carolina hurricanes":   ("hockey", "nhl", "NHL"),
    "hurricanes":            ("hockey", "nhl", "NHL"),
    "florida panthers":      ("hockey", "nhl", "NHL"),
    "panthers":              ("hockey", "nhl", "NHL"),
    "dallas stars":          ("hockey", "nhl", "NHL"),
    "stars":                 ("hockey", "nhl", "NHL"),
    "new york islanders":    ("hockey", "nhl", "NHL"),
    "islanders":             ("hockey", "nhl", "NHL"),
    "new jersey devils":     ("hockey", "nhl", "NHL"),
    "devils":                ("hockey", "nhl", "NHL"),
    "pittsburgh penguins":   ("hockey", "nhl", "NHL"),
    "penguins":              ("hockey", "nhl", "NHL"),
    "detroit red wings":     ("hockey", "nhl", "NHL"),
    "red wings":             ("hockey", "nhl", "NHL"),
    "nashville predators":   ("hockey", "nhl", "NHL"),
    "predators":             ("hockey", "nhl", "NHL"),
    "minnesota wild":        ("hockey", "nhl", "NHL"),
    "wild":                  ("hockey", "nhl", "NHL"),
    "winnipeg jets":         ("hockey", "nhl", "NHL"),
    "jets":                  ("hockey", "nhl", "NHL"),
    "st. louis blues":       ("hockey", "nhl", "NHL"),
    "blues":                 ("hockey", "nhl", "NHL"),
    "seattle kraken":        ("hockey", "nhl", "NHL"),
    "kraken":                ("hockey", "nhl", "NHL"),
    "chicago blackhawks":    ("hockey", "nhl", "NHL"),
    "blackhawks":            ("hockey", "nhl", "NHL"),
    "ottawa senators":       ("hockey", "nhl", "NHL"),
    "senators":              ("hockey", "nhl", "NHL"),
    "calgary flames":        ("hockey", "nhl", "NHL"),
    "flames":                ("hockey", "nhl", "NHL"),
    "vancouver canucks":     ("hockey", "nhl", "NHL"),
    "canucks":               ("hockey", "nhl", "NHL"),
    "buffalo sabres":        ("hockey", "nhl", "NHL"),
    "sabres":                ("hockey", "nhl", "NHL"),
    "san jose sharks":       ("hockey", "nhl", "NHL"),
    "sharks":                ("hockey", "nhl", "NHL"),
    "philadelphia flyers":   ("hockey", "nhl", "NHL"),
    "flyers":                ("hockey", "nhl", "NHL"),
    "anaheim ducks":         ("hockey", "nhl", "NHL"),
    "ducks":                 ("hockey", "nhl", "NHL"),
    "columbus blue jackets": ("hockey", "nhl", "NHL"),
    "washington capitals":   ("hockey", "nhl", "NHL"),
    "capitals":              ("hockey", "nhl", "NHL"),
]

let ESPN_LEAGUES: [(String, String)] = [
    ("soccer", "eng.1"), ("soccer", "esp.1"), ("soccer", "ger.1"),
    ("soccer", "ita.1"), ("soccer", "fra.1"), ("soccer", "usa.1"),
    ("basketball", "nba"),
]

let TEAM_COLORS: [String: String] = [
    "manchester city": "#6CABDD", "manchester united": "#DA291C",
    "liverpool": "#C8102E",       "arsenal": "#EF0107",
    "chelsea": "#034694",         "tottenham": "#132257",
    "newcastle": "#241F20",       "aston villa": "#95BFE5",
    "real madrid": "#FEBE10",     "barcelona": "#A50044",
    "atletico madrid": "#CB3524", "juventus": "#000000",
    "inter milan": "#010E80",     "ac milan": "#FB090B",
    "napoli": "#087AC6",          "paris saint-germain": "#004170",
    "bayern munich": "#DC052D",   "borussia dortmund": "#FDE100",
    "los angeles lakers": "#552583", "golden state warriors": "#1D428A",
    "boston celtics": "#007A33",  "chicago bulls": "#CE1141",
    "miami heat": "#98002E",      "brooklyn nets": "#000000",
    "new york yankees": "#003087","los angeles dodgers": "#005A9C",
    "boston red sox": "#BD3039",  "chicago cubs": "#0E3386",
    "houston astros": "#002D62",  "atlanta braves": "#CE1141",
    "toronto maple leafs": "#003E7E", "montreal canadiens": "#AF1E2D",
    "boston bruins": "#FFB81C",   "edmonton oilers": "#FF4C00",
    "colorado avalanche": "#6F263D", "tampa bay lightning": "#002868",
    "default": "#1A1A2E",
]

let NHL_ABBREVS: [String: String] = [
    "toronto": "TOR",  "maple leafs": "TOR", "leafs": "TOR",
    "montreal": "MTL", "canadiens": "MTL",
    "boston": "BOS",   "bruins": "BOS",
    "new york rangers": "NYR", "rangers": "NYR",
    "new york islanders": "NYI", "islanders": "NYI",
    "new jersey": "NJD", "devils": "NJD",
    "philadelphia": "PHI", "flyers": "PHI",
    "pittsburgh": "PIT", "penguins": "PIT",
    "buffalo": "BUF",  "sabres": "BUF",
    "detroit": "DET",  "red wings": "DET",
    "ottawa": "OTT",   "senators": "OTT",
    "carolina": "CAR", "hurricanes": "CAR",
    "washington": "WSH", "capitals": "WSH",
    "columbus": "CBJ", "blue jackets": "CBJ",
    "florida": "FLA",  "panthers": "FLA",
    "tampa bay": "TBL","lightning": "TBL",
    "nashville": "NSH","predators": "NSH",
    "chicago": "CHI",  "blackhawks": "CHI",
    "st. louis": "STL","blues": "STL",
    "minnesota": "MIN","wild": "MIN",
    "winnipeg": "WPG", "jets": "WPG",
    "dallas": "DAL",   "stars": "DAL",
    "colorado": "COL", "avalanche": "COL",
    "edmonton": "EDM", "oilers": "EDM",
    "calgary": "CGY",  "flames": "CGY",
    "vancouver": "VAN","canucks": "VAN",
    "seattle": "SEA",  "kraken": "SEA",
    "vegas": "VGK",    "golden knights": "VGK",
    "utah": "UTA",     "arizona": "UTA",
    "san jose": "SJS", "sharks": "SJS",
    "anaheim": "ANA",  "ducks": "ANA",
    "los angeles": "LAK", "kings": "LAK",
]

// MARK: - HTTP Helpers

let HTTP_HEADERS: [String: String] = [
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36",
    "Accept-Language": "en-US,en;q=0.9",
]

func logErr(_ msg: String) {
    fputs("  \(msg)\n", stderr)
}

func getJSON(url: URL) async -> Any? {
    try? await Task.sleep(nanoseconds: 500_000_000)
    var req = URLRequest(url: url)
    for (k, v) in HTTP_HEADERS { req.setValue(v, forHTTPHeaderField: k) }
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200 else {
        logErr("[http] failed: \(url.absoluteString.suffix(80))")
        return nil
    }
    return try? JSONSerialization.jsonObject(with: data)
}

func getXML(url: URL) async -> String? {
    try? await Task.sleep(nanoseconds: 500_000_000)
    var req = URLRequest(url: url)
    for (k, v) in HTTP_HEADERS { req.setValue(v, forHTTPHeaderField: k) }
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
    return String(data: data, encoding: .utf8)
}

// MARK: - Sport Detection

func detectSport(teamName: String) async -> SportEntry {
    let lower = teamName.lowercased().trimmingCharacters(in: .whitespaces)
    for (key, entry) in KNOWN_TEAMS {
        if key.contains(lower) || lower.contains(key) {
            logErr("[detect] matched known team: '\(key)' → \(entry.display)")
            return entry
        }
    }
    logErr("[detect] not in known list, searching ESPN leagues...")
    for (sport, league) in ESPN_LEAGUES {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(sport)/\(league)/teams"),
              let data = await getJSON(url: url) as? [String: Any],
              let teams = (data["sports"] as? [[String: Any]])?.first?["leagues"] as? [[String: Any]],
              let entries = teams.first?["teams"] as? [[String: Any]] else { continue }
        for entry in entries {
            let t = entry["team"] as? [String: Any] ?? [:]
            let name = (t["displayName"] as? String ?? "").lowercased()
            let nick = (t["nickname"] as? String ?? "").lowercased()
            if lower.contains(name) || name.contains(lower) || nick.contains(lower) {
                logErr("[detect] ESPN match: \(t["displayName"] as? String ?? "") in \(league)")
                return (sport, league, league.uppercased())
            }
        }
    }
    logErr("[detect] could not detect sport, defaulting to PL soccer")
    return ("soccer", "eng.1", "Premier League")
}

// MARK: - ESPN (soccer + basketball)

let ESPN_BASE = "https://site.api.espn.com/apis/site/v2/sports"
let ESPN_CORE = "https://sports.core.api.espn.com/v2/sports"

func espnFindTeamId(teamName: String, sport: String, league: String) async -> String? {
    guard let url = URL(string: "\(ESPN_BASE)/\(sport)/\(league)/teams"),
          let data = await getJSON(url: url) as? [String: Any],
          let teams = ((data["sports"] as? [[String: Any]])?.first?["leagues"] as? [[String: Any]])?.first?["teams"] as? [[String: Any]] else { return nil }
    let lower = teamName.lowercased()
    var bestId: String? = nil
    var bestScore = 0
    for entry in teams {
        let t = entry["team"] as? [String: Any] ?? [:]
        let name = (t["displayName"] as? String ?? "").lowercased()
        let nick = (t["nickname"] as? String ?? "").lowercased()
        let slug = (t["slug"] as? String ?? "").lowercased()
        var score = 0
        if lower == name                                     { score = 100 }
        else if lower.contains(name) || name.contains(lower){ score = 80  }
        else if nick.contains(lower) || lower.contains(nick){ score = 60  }
        else if slug.contains(lower)                        { score = 50  }
        else if lower.split(separator: " ").filter({ $0.count > 3 }).contains(where: { name.contains($0) }) { score = 30 }
        if score > bestScore { bestScore = score; bestId = t["id"] as? String }
    }
    logErr("[espn] team ID = \(bestId ?? "nil") (score=\(bestScore))")
    return bestId
}

func espnNextGame(teamId: String, sport: String, league: String) async -> GameInfo? {
    guard let url = URL(string: "\(ESPN_BASE)/\(sport)/\(league)/teams/\(teamId)/schedule"),
          let data = await getJSON(url: url) as? [String: Any],
          let events = data["events"] as? [[String: Any]] else { return nil }
    for event in events {
        guard let comp = (event["competitions"] as? [[String: Any]])?.first else { continue }
        let state = ((comp["status"] as? [String: Any])?["type"] as? [String: Any])?["state"] as? String ?? ""
        guard state == "pre" else { continue }
        let competitors = comp["competitors"] as? [[String: Any]] ?? []
        let home = competitors.first(where: { ($0["homeAway"] as? String) == "home" }) ?? [:]
        let away = competitors.first(where: { ($0["homeAway"] as? String) == "away" }) ?? [:]
        let homeTeam = home["team"] as? [String: Any] ?? [:]
        let awayTeam = away["team"] as? [String: Any] ?? [:]
        return GameInfo(
            eventId:     event["id"] as? String ?? "",
            homeTeam:    homeTeam["displayName"] as? String ?? "",
            awayTeam:    awayTeam["displayName"] as? String ?? "",
            homeId:      homeTeam["id"] as? String ?? "",
            awayId:      awayTeam["id"] as? String ?? "",
            venue:       (comp["venue"] as? [String: Any])?["fullName"] as? String ?? "TBD",
            dateISO:     event["date"] as? String ?? "",
            competition: (data["season"] as? [String: Any])?["displayName"] as? String ?? ""
        )
    }
    return nil
}

func espnRoster(teamId: String, sport: String, league: String) async -> [RawPlayer] {
    guard let url = URL(string: "\(ESPN_BASE)/\(sport)/\(league)/teams/\(teamId)/roster"),
          let data = await getJSON(url: url) as? [String: Any],
          let athletes = data["athletes"] as? [[String: Any]] else { return [] }
    var players: [RawPlayer] = []
    for item in athletes {
        if let items = item["items"] as? [[String: Any]] {
            players.append(contentsOf: items.map(parseEspnAthlete))
        } else {
            players.append(parseEspnAthlete(item))
        }
    }
    logErr("[espn] roster: \(players.count) players")
    return players
}

func parseEspnAthlete(_ a: [String: Any]) -> RawPlayer {
    RawPlayer(
        id:       a["id"] as? String ?? "",
        name:     a["displayName"] as? String ?? a["fullName"] as? String ?? "",
        number:   Int(a["jersey"] as? String ?? ""),
        position: (a["position"] as? [String: Any])?["abbreviation"] as? String ?? "",
        age:      a["age"] as? Int
    )
}

func espnPlayerStats(playerId: String, sport: String, league: String) async -> [String: String] {
    guard let url = URL(string: "\(ESPN_CORE)/\(sport)/leagues/\(league)/athletes/\(playerId)/statistics/0"),
          let data = await getJSON(url: url) as? [String: Any],
          let categories = (data["splits"] as? [String: Any])?["categories"] as? [[String: Any]] else { return [:] }
    var stats: [String: String] = [:]
    for cat in categories {
        for stat in (cat["stats"] as? [[String: Any]] ?? []) {
            let name  = stat["displayName"] as? String ?? ""
            let value = stat["displayValue"] as? String ?? "—"
            if !name.isEmpty && !["", "0", "0.0"].contains(value) { stats[name] = value }
        }
    }
    return stats
}

func espnTeamNews(teamId: String, sport: String, league: String) async -> [String] {
    guard let url = URL(string: "\(ESPN_BASE)/\(sport)/\(league)/news?team=\(teamId)&limit=10"),
          let data = await getJSON(url: url) as? [String: Any],
          let articles = data["articles"] as? [[String: Any]] else { return [] }
    return articles.compactMap { ($0["headline"] as? String)?.trimmingCharacters(in: .whitespaces) }
                   .filter { !$0.isEmpty }.prefix(6).map { $0 }
}

// MARK: - MLB

let MLB_BASE = "https://statsapi.mlb.com/api/v1"

func mlbFindTeamId(teamName: String) async -> String? {
    guard let url = URL(string: "\(MLB_BASE)/teams?sportId=1"),
          let data = await getJSON(url: url) as? [String: Any],
          let teams = data["teams"] as? [[String: Any]] else { return nil }
    let lower = teamName.lowercased()
    for team in teams {
        let name  = (team["name"] as? String ?? "").lowercased()
        let short = (team["teamName"] as? String ?? "").lowercased()
        if lower.contains(name) || name.contains(lower) || lower.contains(short) {
            let id = String(team["id"] as? Int ?? 0)
            logErr("[mlb] team ID = \(id) (\(team["name"] as? String ?? ""))")
            return id
        }
    }
    return nil
}

func mlbNextGame(teamId: String) async -> GameInfo? {
    guard let url = URL(string: "\(MLB_BASE)/schedule/games/?sportId=1&teamId=\(teamId)"),
          let data = await getJSON(url: url) as? [String: Any],
          let dates = data["dates"] as? [[String: Any]], !dates.isEmpty,
          let game  = (dates[0]["games"] as? [[String: Any]])?.first else { return nil }
    let homeTeam = (game["teams"] as? [String: Any])?["home"] as? [String: Any]
    let awayTeam = (game["teams"] as? [String: Any])?["away"] as? [String: Any]
    return GameInfo(
        eventId:     String(game["gamePk"] as? Int ?? 0),
        homeTeam:    (homeTeam?["team"] as? [String: Any])?["name"] as? String ?? "",
        awayTeam:    (awayTeam?["team"] as? [String: Any])?["name"] as? String ?? "",
        homeId:      String((homeTeam?["team"] as? [String: Any])?["id"] as? Int ?? 0),
        awayId:      String((awayTeam?["team"] as? [String: Any])?["id"] as? Int ?? 0),
        venue:       (game["venue"] as? [String: Any])?["name"] as? String ?? "TBD",
        dateISO:     game["gameDate"] as? String ?? "",
        competition: "MLB"
    )
}

func mlbRoster(teamId: String) async -> [RawPlayer] {
    guard let url = URL(string: "\(MLB_BASE)/teams/\(teamId)/roster?season=2026&rosterType=active"),
          let data = await getJSON(url: url) as? [String: Any],
          let roster = data["roster"] as? [[String: Any]] else { return [] }
    let players = roster.map { entry -> RawPlayer in
        let person = entry["person"] as? [String: Any] ?? [:]
        return RawPlayer(
            id:       String(person["id"] as? Int ?? 0),
            name:     person["fullName"] as? String ?? "",
            number:   Int(entry["jerseyNumber"] as? String ?? ""),
            position: (entry["position"] as? [String: Any])?["abbreviation"] as? String ?? "",
            age:      nil
        )
    }
    logErr("[mlb] roster: \(players.count) players")
    return players
}

func mlbPlayerStats(playerId: String) async -> [String: String] {
    for group in ["hitting", "pitching"] {
        guard let url = URL(string: "\(MLB_BASE)/people/\(playerId)/stats?stats=season&season=2026&group=\(group)"),
              let data = await getJSON(url: url) as? [String: Any],
              let splits = (data["stats"] as? [[String: Any]])?.first?["splits"] as? [[String: Any]],
              !splits.isEmpty,
              let stat = splits[0]["stat"] as? [String: Any] else { continue }
        var result: [String: String] = [:]
        for (k, v) in stat {
            let s = "\(v)"
            if !["0", "0.0", ".000", "", "null"].contains(s) { result[k] = s }
        }
        if !result.isEmpty { return result }
    }
    return [:]
}

// MARK: - NHL

let NHL_BASE = "https://api-web.nhle.com/v1"

func nhlAbbrev(teamName: String) -> String? {
    let lower = teamName.lowercased()
    for (key, abbrev) in NHL_ABBREVS {
        if lower.contains(key) { return abbrev }
    }
    return nil
}

func nhlNextGame(abbrev: String) async -> GameInfo? {
    guard let url = URL(string: "\(NHL_BASE)/club-schedule-season/\(abbrev)/now"),
          let data = await getJSON(url: url) as? [String: Any],
          let games = data["games"] as? [[String: Any]] else { return nil }
    for game in games {
        let state = game["gameState"] as? String ?? ""
        guard ["FUT", "PRE"].contains(state) else { continue }
        let home = game["homeTeam"] as? [String: Any] ?? [:]
        let away = game["awayTeam"] as? [String: Any] ?? [:]
        let homeName = [home["placeName"] as? [String: Any], home["commonName"] as? [String: Any]]
            .compactMap { $0?["default"] as? String }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        let awayName = [away["placeName"] as? [String: Any], away["commonName"] as? [String: Any]]
            .compactMap { $0?["default"] as? String }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return GameInfo(
            eventId:     String(game["id"] as? Int ?? 0),
            homeTeam:    homeName,
            awayTeam:    awayName,
            homeId:      home["abbrev"] as? String ?? "",
            awayId:      away["abbrev"] as? String ?? "",
            venue:       (game["venue"] as? [String: Any])?["default"] as? String ?? "TBD",
            dateISO:     game["gameDate"] as? String ?? "",
            competition: "NHL"
        )
    }
    return nil
}

func nhlRoster(abbrev: String) async -> [RawPlayer] {
    guard let url = URL(string: "\(NHL_BASE)/roster/\(abbrev)/current"),
          let data = await getJSON(url: url) as? [String: Any] else { return [] }
    var players: [RawPlayer] = []
    for group in ["forwards", "defensemen", "goalies"] {
        for p in (data[group] as? [[String: Any]] ?? []) {
            let firstName = (p["firstName"] as? [String: Any])?["default"] as? String ?? ""
            let lastName  = (p["lastName"]  as? [String: Any])?["default"] as? String ?? ""
            let birthDate = p["birthDate"] as? String ?? ""
            players.append(RawPlayer(
                id:       String(p["id"] as? Int ?? 0),
                name:     "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces),
                number:   p["sweaterNumber"] as? Int,
                position: p["positionCode"] as? String ?? "",
                age:      birthDate.isEmpty ? nil : calcAge(birthDate: birthDate)
            ))
        }
    }
    logErr("[nhl] roster: \(players.count) players")
    return players
}

func nhlPlayerStats(playerId: String) async -> [String: String] {
    guard let url = URL(string: "\(NHL_BASE)/player/\(playerId)/landing"),
          let data = await getJSON(url: url) as? [String: Any],
          let totals = data["seasonTotals"] as? [[String: Any]], !totals.isEmpty else { return [:] }
    let latest = totals[totals.count - 1]
    let keys = ["goals","assists","points","plusMinus","pim","shots",
                "gamesPlayed","savePctg","goalsAgainstAvg","shutouts","wins"]
    var stats: [String: String] = [:]
    for key in keys {
        if let val = latest[key], "\(val)" != "0" { stats[key] = "\(val)" }
    }
    return stats
}

// MARK: - Google News RSS

func googleNews(query: String, maxResults: Int = 5) async -> [String] {
    guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let url = URL(string: "https://news.google.com/rss/search?q=\(encoded)&hl=en-US&gl=US&ceid=US:en"),
          let xml = await getXML(url: url) else { return [] }
    var headlines: [String] = []
    let pattern = try! NSRegularExpression(pattern: "<title><!\\[CDATA\\[(.*?)\\]\\]></title>|<title>(.*?)</title>")
    let range = NSRange(xml.startIndex..., in: xml)
    for match in pattern.matches(in: xml, range: range) {
        let raw: String
        if let r = Range(match.range(at: 1), in: xml) { raw = String(xml[r]).trimmingCharacters(in: .whitespaces) }
        else if let r = Range(match.range(at: 2), in: xml) { raw = String(xml[r]).trimmingCharacters(in: .whitespaces) }
        else { continue }
        guard !raw.isEmpty, raw != "Google News" else { continue }
        let clean = raw.replacingOccurrences(of: "\\s*-\\s*[^-]+$", with: "", options: .regularExpression)
                       .trimmingCharacters(in: .whitespaces)
        if !clean.isEmpty { headlines.append(clean) }
        if headlines.count >= maxResults { break }
    }
    return headlines
}

func fetchNewsForTeam(_ teamName: String)   async -> [String] { await googleNews(query: "\(teamName) news 2026", maxResults: 6) }
func fetchNewsForPlayer(_ name: String, _ team: String) async -> [String] { await googleNews(query: "\(name) \(team) 2026", maxResults: 3) }
func fetchInjuryReport(_ teamName: String)  async -> [String] { await googleNews(query: "\(teamName) injury suspended doubtful out 2026", maxResults: 8) }

// MARK: - Storyline / Status

func makeStoryline(name: String, position: String, stats: [String: String], news: [String], status: String) -> String {
    if ["injured", "doubtful", "suspended"].contains(status) {
        return "\(name) is listed as \(status) — his availability is the key team news heading in."
    }
    if let headline = news.first {
        let clean = headline.replacingOccurrences(of: "\\s*-\\s*[^-]+$", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        if clean.count > 10 { return clean }
    }
    if let (key, val) = stats.first {
        return "\(name) brings \(val) \(key) into this matchup — one of the key figures to watch."
    }
    return "\(name) is a key \(position) piece in this lineup — watch how they influence the game."
}

func makeMatchupNote(name: String, opponent: String) -> String {
    "\(name) faces \(opponent) — a key individual battle to monitor throughout."
}

func inferStatus(playerName: String, injuryHeadlines: [String]) -> Player.PlayerStatus {
    let parts = playerName.lowercased().split(separator: " ").filter { $0.count > 2 }.map(String.init)
    for headline in injuryHeadlines {
        let hl = headline.lowercased()
        guard parts.contains(where: { hl.contains($0) }) else { continue }
        if hl.contains("suspend")                                                         { return .suspended }
        if hl.contains("doubtful")                                                        { return .doubtful  }
        if ["out","ruled out","injured","sidelined","misses"].contains(where: hl.contains) { return .injured   }
    }
    return .fit
}

// MARK: - Utilities

func calcAge(birthDate: String) -> Int? {
    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
    guard let bd = df.date(from: birthDate) else { return nil }
    let cal = Calendar.current
    return cal.dateComponents([.year], from: bd, to: Date()).year
}

func teamColor(_ teamName: String) -> String {
    let lower = teamName.lowercased()
    for (key, color) in TEAM_COLORS { if lower.contains(key) { return color } }
    return TEAM_COLORS["default"]!
}

func makeId(_ parts: String...) -> String {
    let raw = parts.filter { !$0.isEmpty }.joined(separator: "-").lowercased().trimmingCharacters(in: .whitespaces)
    let result = raw.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return result.isEmpty ? "unknown" : result
}

func topStats(_ stats: [String: String], limit: Int = 3) -> [String] {
    stats.filter { !["—", "", "0", "0.0", "None"].contains($0.value) }
         .prefix(limit).map { "\($0.value) \($0.key)" }
}

// MARK: - Main Orchestrator

func buildGameCache(teamName: String) async throws -> GameCache {
    fputs("\n\("=".repeated(50))\n", stderr)
    fputs("BroadcastBrain Cache Builder — \(teamName)\n", stderr)
    fputs("\("=".repeated(50))\n\n", stderr)

    fputs("[1/5] Detecting sport...\n", stderr)
    let (sport, league, competitionDisplay) = await detectSport(teamName: teamName)
    fputs("      → \(competitionDisplay)\n\n", stderr)

    fputs("[2/5] Finding next game...\n", stderr)
    var gameInfo: GameInfo? = nil
    var ourTeamId = ""

    if sport == "soccer" || sport == "basketball" {
        ourTeamId = await espnFindTeamId(teamName: teamName, sport: sport, league: league) ?? ""
        if !ourTeamId.isEmpty { gameInfo = await espnNextGame(teamId: ourTeamId, sport: sport, league: league) }
    } else if sport == "baseball" {
        ourTeamId = await mlbFindTeamId(teamName: teamName) ?? ""
        if !ourTeamId.isEmpty { gameInfo = await mlbNextGame(teamId: ourTeamId) }
    } else if sport == "hockey" {
        ourTeamId = nhlAbbrev(teamName: teamName) ?? ""
        if !ourTeamId.isEmpty { gameInfo = await nhlNextGame(abbrev: ourTeamId) }
    }

    if gameInfo == nil {
        logErr("[2/5] No upcoming game in API, trying Google News...")
        let newsHints = await googleNews(query: "\(teamName) next match fixture 2026", maxResults: 8)
        var opponentHint = ""
        for headline in newsHints {
            let hl = headline.lowercased()
            let teamWords = teamName.lowercased().split(separator: " ").filter { $0.count > 3 }.map(String.init)
            guard teamWords.contains(where: { hl.contains($0) }) else { continue }
            for (known, _) in KNOWN_TEAMS {
                if hl.contains(known) && !teamName.lowercased().contains(known) {
                    if known.count > opponentHint.count { opponentHint = known }
                }
            }
            if !opponentHint.isEmpty {
                opponentHint = opponentHint.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
                logErr("[2/5] Extracted opponent: '\(opponentHint)'")
                break
            }
        }
        gameInfo = GameInfo(eventId: "tbd", homeTeam: teamName,
                            awayTeam: opponentHint.isEmpty ? "TBD" : opponentHint,
                            homeId: ourTeamId, awayId: "",
                            venue: "TBD", dateISO: ISO8601DateFormatter().string(from: Date()),
                            competition: competitionDisplay)
    }

    let gi = gameInfo!
    fputs("      → \(gi.homeTeam) vs \(gi.awayTeam) at \(gi.venue)\n\n", stderr)

    fputs("[3/5] Fetching rosters...\n", stderr)
    var homeRaw: [RawPlayer] = []
    var awayRaw:  [RawPlayer] = []

    let isHome    = teamName.lowercased().contains(gi.homeTeam.lowercased()) || gi.homeTeam.lowercased().contains(teamName.lowercased())
    let oppName   = isHome ? gi.awayTeam : gi.homeTeam
    var oppApiId  = isHome ? gi.awayId   : gi.homeId

    if sport == "soccer" || sport == "basketball" {
        if !ourTeamId.isEmpty { homeRaw = await espnRoster(teamId: ourTeamId, sport: sport, league: league) }
        if oppApiId.isEmpty && oppName != "TBD" { oppApiId = await espnFindTeamId(teamName: oppName, sport: sport, league: league) ?? "" }
        if !oppApiId.isEmpty { awayRaw = await espnRoster(teamId: oppApiId, sport: sport, league: league) }
    } else if sport == "baseball" {
        if !ourTeamId.isEmpty { homeRaw = await mlbRoster(teamId: ourTeamId) }
        if oppName != "TBD" {
            let oppId = oppApiId.isEmpty ? (await mlbFindTeamId(teamName: oppName) ?? "") : oppApiId
            if !oppId.isEmpty { awayRaw = await mlbRoster(teamId: oppId) }
        }
    } else if sport == "hockey" {
        if !ourTeamId.isEmpty { homeRaw = await nhlRoster(abbrev: ourTeamId) }
        if oppName != "TBD" {
            let oppAbbr = oppApiId.isEmpty ? (nhlAbbrev(teamName: oppName) ?? "") : oppApiId
            if !oppAbbr.isEmpty { awayRaw = await nhlRoster(abbrev: oppAbbr) }
        }
    }
    fputs("      → Home: \(homeRaw.count) | Away: \(awayRaw.count)\n\n", stderr)

    fputs("[4/5] Fetching news & injuries...\n", stderr)
    let homeInjuries = await fetchInjuryReport(gi.homeTeam)
    let awayInjuries = gi.awayTeam != "TBD" ? await fetchInjuryReport(gi.awayTeam) : []
    let allInjuries  = homeInjuries + awayInjuries
    let homeNews     = await fetchNewsForTeam(gi.homeTeam)
    let awayNews     = gi.awayTeam != "TBD" ? await fetchNewsForTeam(gi.awayTeam) : []
    var storylines   = Array((homeNews.prefix(3) + awayNews.prefix(2)))
    if (sport == "soccer" || sport == "basketball") && !ourTeamId.isEmpty {
        let espnNews = await espnTeamNews(teamId: ourTeamId, sport: sport, league: league)
        storylines = Array((espnNews.prefix(3) + storylines).prefix(8))
    }
    fputs("      → \(storylines.count) storylines, \(allInjuries.count) injury items\n\n", stderr)

    fputs("[5/5] Building player records...\n", stderr)
    let homeIdStr = makeId(gi.homeTeam)
    let awayIdStr = makeId(gi.awayTeam)

    func buildPlayerList(raw: [RawPlayer], teamIdStr: String, teamDisplay: String, oppDisplay: String) async -> [Player] {
        var built: [Player] = []
        for (i, p) in raw.prefix(20).enumerated() {
            let name     = p.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Player \(i+1)" : p.name.trimmingCharacters(in: .whitespaces)
            let playerId = p.id.isEmpty ? makeId(teamIdStr, name) : p.id

            var stats: [String: String] = [:]
            if i < 10 && !playerId.isEmpty {
                logErr("→ Fetching stats for \(name)...")
                if sport == "soccer" || sport == "basketball" { stats = await espnPlayerStats(playerId: playerId, sport: sport, league: league) }
                else if sport == "baseball" { stats = await mlbPlayerStats(playerId: playerId) }
                else if sport == "hockey"   { stats = await nhlPlayerStats(playerId: playerId) }
            }
            var playerNews: [String] = []
            if i < 6 {
                logErr("→ Fetching news for \(name)...")
                playerNews = await fetchNewsForPlayer(name, teamDisplay)
            }
            let status = inferStatus(playerName: name, injuryHeadlines: allInjuries)
            built.append(Player(
                id:            makeId(teamIdStr, name),
                teamId:        teamIdStr,
                shirtNumber:   p.number ?? (i + 1),
                name:          name,
                position:      p.position.isEmpty ? "—" : p.position,
                age:           p.age ?? 0,
                stats:         PlayerStats(season: stats, formLast5: [:], vsOpponent: [:]),
                storyline:     makeStoryline(name: name, position: p.position, stats: stats, news: playerNews, status: status.rawValue),
                matchupNote:   makeMatchupNote(name: name, opponent: oppDisplay),
                topStats:      topStats(stats),
                status:        status,
                newsHeadlines: playerNews
            ))
        }
        return built
    }

    let homePlayers = await buildPlayerList(raw: homeRaw, teamIdStr: homeIdStr, teamDisplay: gi.homeTeam, oppDisplay: gi.awayTeam)
    let awayPlayers = await buildPlayerList(raw: awayRaw, teamIdStr: awayIdStr, teamDisplay: gi.awayTeam, oppDisplay: gi.homeTeam)
    fputs("      → Built \(homePlayers.count) home + \(awayPlayers.count) away player records\n\n", stderr)

    return GameCache(
        match: MatchInfo(id: makeId(gi.homeTeam, gi.awayTeam), homeTeam: gi.homeTeam, awayTeam: gi.awayTeam,
                         competition: gi.competition.isEmpty ? competitionDisplay : gi.competition,
                         venue: gi.venue, kickoffISO: gi.dateISO.isEmpty ? ISO8601DateFormatter().string(from: Date()) : gi.dateISO),
        teams: TeamsPayload(
            home: Team(id: homeIdStr, name: gi.homeTeam, colorHex: teamColor(gi.homeTeam), record: [:]),
            away: Team(id: awayIdStr, name: gi.awayTeam, colorHex: teamColor(gi.awayTeam), record: [:])
        ),
        players:     homePlayers + awayPlayers,
        storylines:  storylines,
        source:      "espn_unofficial + mlb_official + nhl_official + google_news_rss",
        generatedAt: ISO8601DateFormatter().string(from: Date())
    )
}

// MARK: - String helper

extension String {
    func repeated(_ count: Int) -> String { String(repeating: self, count: count) }
}

// MARK: - Entry Point

let args = CommandLine.arguments.dropFirst()
guard !args.isEmpty else {
    print("Usage: swift src/data/FetchGame.swift <team name>")
    print("  e.g. swift src/data/FetchGame.swift 'Manchester City'")
    print("  e.g. swift src/data/FetchGame.swift 'Los Angeles Lakers'")
    print("  e.g. swift src/data/FetchGame.swift 'New York Yankees'")
    print("  e.g. swift src/data/FetchGame.swift 'Toronto Maple Leafs'")
    exit(1)
}

let teamName = args.joined(separator: " ")

let cache = try await buildGameCache(teamName: teamName)

let outDir  = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("assets")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let outPath = outDir.appendingPathComponent("game_cache.json")
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(cache).write(to: outPath)

print("\n✓ Wrote \(outPath.path)")
print("  Match:      \(cache.match.homeTeam) vs \(cache.match.awayTeam)")
print("  Venue:      \(cache.match.venue)")
print("  Kickoff:    \(cache.match.kickoffISO)")
print("  Players:    \(cache.players.count)")
print("  Storylines: \(cache.storylines.count)")

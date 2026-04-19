import Foundation

// MARK: - Progress

enum FetchStep: String {
    case detectingSport  = "Detecting sport…"
    case findingGame     = "Finding next game…"
    case fetchingRosters = "Fetching rosters…"
    case fetchingNews    = "Fetching news & storylines…"
    case buildingCache   = "Building match cache…"
    case done            = "Done"
}

@Observable
final class GameFetchService {
    var step: FetchStep = .detectingSport
    var stepDetail: String = ""
    var isRunning = false

    // MARK: - Entry point

    func buildMatchCache(teamName: String) async throws -> MatchCache {
        isRunning = true
        defer { isRunning = false }

        progress(.detectingSport, "")
        let (sport, league, display) = await detectSport(teamName)

        progress(.findingGame, "")
        var gameInfo: GameInfo? = nil
        var ourTeamId = ""

        if sport == "soccer" || sport == "basketball" {
            ourTeamId = await espnFindTeamId(teamName, sport: sport, league: league) ?? ""
            if !ourTeamId.isEmpty { gameInfo = await espnNextGame(teamId: ourTeamId, sport: sport, league: league) }
        } else if sport == "baseball" {
            ourTeamId = await mlbFindTeamId(teamName) ?? ""
            if !ourTeamId.isEmpty { gameInfo = await mlbNextGame(teamId: ourTeamId) }
        } else if sport == "hockey" {
            ourTeamId = nhlAbbrev(teamName) ?? ""
            if !ourTeamId.isEmpty { gameInfo = await nhlNextGame(abbrev: ourTeamId) }
        }

        // Fallback if no upcoming game found
        let gi = gameInfo ?? GameInfo(
            homeTeam: teamName, awayTeam: "TBD",
            homeId: ourTeamId, awayId: "",
            venue: "TBD", dateISO: ISO8601DateFormatter().string(from: Date()),
            competition: display
        )
        progress(.findingGame, "\(gi.homeTeam) vs \(gi.awayTeam)")

        progress(.fetchingRosters, "")
        let isHome   = teamName.lowercased().contains(gi.homeTeam.lowercased()) || gi.homeTeam.lowercased().contains(teamName.lowercased())
        let oppName  = isHome ? gi.awayTeam : gi.homeTeam
        var oppId    = isHome ? gi.awayId   : gi.homeId

        var homeRaw: [RawPlayerInfo] = []
        var awayRaw: [RawPlayerInfo] = []

        if sport == "soccer" || sport == "basketball" {
            if !ourTeamId.isEmpty { homeRaw = await espnRoster(teamId: ourTeamId, sport: sport, league: league) }
            if oppId.isEmpty && oppName != "TBD" { oppId = await espnFindTeamId(oppName, sport: sport, league: league) ?? "" }
            if !oppId.isEmpty { awayRaw = await espnRoster(teamId: oppId, sport: sport, league: league) }
        } else if sport == "baseball" {
            if !ourTeamId.isEmpty { homeRaw = await mlbRoster(teamId: ourTeamId) }
            if oppName != "TBD" {
                let id = oppId.isEmpty ? (await mlbFindTeamId(oppName) ?? "") : oppId
                if !id.isEmpty { awayRaw = await mlbRoster(teamId: id) }
            }
        } else if sport == "hockey" {
            if !ourTeamId.isEmpty { homeRaw = await nhlRoster(abbrev: ourTeamId) }
            if oppName != "TBD" {
                let abbr = oppId.isEmpty ? (nhlAbbrev(oppName) ?? "") : oppId
                if !abbr.isEmpty { awayRaw = await nhlRoster(abbrev: abbr) }
            }
        }
        progress(.fetchingRosters, "\(homeRaw.count) + \(awayRaw.count) players")

        progress(.fetchingNews, "")
        let homeNews = await googleNews("\(gi.homeTeam) news 2026", max: 5)
        let awayNews = gi.awayTeam != "TBD" ? await googleNews("\(gi.awayTeam) news 2026", max: 3) : []
        var storylines = Array((homeNews + awayNews).prefix(8))
        if (sport == "soccer" || sport == "basketball") && !ourTeamId.isEmpty {
            let espnH = await espnTeamNews(teamId: ourTeamId, sport: sport, league: league)
            storylines = Array((espnH.prefix(4) + storylines).prefix(8))
        }

        progress(.buildingCache, "")
        let injuryLines = await googleNews("\(gi.homeTeam) injury doubtful out 2026", max: 8)
            + (gi.awayTeam != "TBD" ? await googleNews("\(gi.awayTeam) injury doubtful out 2026", max: 5) : [])

        var players: [Player] = []
        for (raw, teamDisplay, oppDisplay) in [(homeRaw, gi.homeTeam, gi.awayTeam), (awayRaw, gi.awayTeam, gi.homeTeam)] {
            for (i, p) in raw.prefix(18).enumerated() {
                var stats: [String: String] = [:]
                if i < 8 && !p.id.isEmpty {
                    if sport == "soccer" || sport == "basketball" {
                        stats = await espnPlayerStats(playerId: p.id, sport: sport, league: league)
                    } else if sport == "baseball" {
                        stats = await mlbPlayerStats(playerId: p.id)
                    } else if sport == "hockey" {
                        stats = await nhlPlayerStats(playerId: p.id)
                    }
                }
                var playerNews: [String] = []
                if i < 6 {
                    playerNews = await fetchNewsForPlayer(name: p.name, team: teamDisplay)
                }
                let status = inferStatus(name: p.name, headlines: injuryLines)
                var keyStats: [String: String] = [:]
                let statPairs = stats.filter { !["","0","0.0","—"].contains($0.value) }
                let topThree = statPairs.prefix(4)
                let keys = ["stat1","stat2","stat3","stat4"]
                for (idx, kv) in topThree.enumerated() {
                    keyStats[keys[idx]] = "\(kv.value) \(kv.key)"
                }
                keyStats["storyHero"] = makeStoryline(name: p.name, position: p.position, stats: stats, news: playerNews, status: status)
                keyStats["tactical"]  = makeMatchupNote(name: p.name, opponent: oppDisplay)
                players.append(Player(
                    name: p.name.isEmpty ? "Player \(i+1)" : p.name,
                    team: teamDisplay,
                    jersey: p.number.map(String.init) ?? "\(i+1)",
                    position: p.position.isEmpty ? "—" : p.position,
                    keyStats: keyStats
                ))
            }
        }

        let title = "\(gi.homeTeam) vs \(gi.awayTeam) · \(gi.competition.isEmpty ? display : gi.competition) · \(gi.venue)"
        let facts  = [
            "Match: \(gi.homeTeam) vs \(gi.awayTeam)",
            "Competition: \(gi.competition.isEmpty ? display : gi.competition)",
            "Venue: \(gi.venue)",
            "Date: \(gi.dateISO)",
        ] + storylines.prefix(4).map { $0 }

        progress(.done, title)
        return MatchCache(
            matchId:    makeId(gi.homeTeam, gi.awayTeam),
            title:      title,
            players:    players,
            facts:      facts,
            storylines: storylines
        )
    }

    // MARK: - Progress helper

    private func progress(_ s: FetchStep, _ detail: String) {
        step = s; stepDetail = detail
    }

    // MARK: - Sport detection

    private func detectSport(_ teamName: String) async -> (String, String, String) {
        let lower = teamName.lowercased().trimmingCharacters(in: .whitespaces)
        for (key, entry) in Self.knownTeams {
            if key.contains(lower) || lower.contains(key) { return entry }
        }
        // ESPN search fallback
        for (sport, league) in [("soccer","eng.1"),("soccer","esp.1"),("soccer","ger.1"),("basketball","nba")] {
            guard let url = URL(string: "\(Self.espnBase)/\(sport)/\(league)/teams"),
                  let data = await getJSON(url) as? [String: Any],
                  let teams = ((data["sports"] as? [[String:Any]])?.first?["leagues"] as? [[String:Any]])?.first?["teams"] as? [[String:Any]] else { continue }
            for entry in teams {
                let t = entry["team"] as? [String:Any] ?? [:]
                let name = (t["displayName"] as? String ?? "").lowercased()
                let nick = (t["nickname"] as? String ?? "").lowercased()
                if lower.contains(name) || name.contains(lower) || nick.contains(lower) {
                    return (sport, league, league.uppercased())
                }
            }
        }
        return ("soccer", "eng.1", "Premier League")
    }

    // MARK: - ESPN

    private func espnFindTeamId(_ teamName: String, sport: String, league: String) async -> String? {
        guard let url = URL(string: "\(Self.espnBase)/\(sport)/\(league)/teams"),
              let data = await getJSON(url) as? [String: Any],
              let teams = ((data["sports"] as? [[String:Any]])?.first?["leagues"] as? [[String:Any]])?.first?["teams"] as? [[String:Any]] else { return nil }
        let lower = teamName.lowercased()
        var bestId: String?; var bestScore = 0
        for entry in teams {
            let t = entry["team"] as? [String:Any] ?? [:]
            let name = (t["displayName"] as? String ?? "").lowercased()
            let nick = (t["nickname"] as? String ?? "").lowercased()
            let slug = (t["slug"] as? String ?? "").lowercased()
            var score = 0
            if lower == name                                      { score = 100 }
            else if lower.contains(name) || name.contains(lower) { score = 80  }
            else if nick.contains(lower) || lower.contains(nick) { score = 60  }
            else if slug.contains(lower)                         { score = 50  }
            if score > bestScore { bestScore = score; bestId = t["id"] as? String }
        }
        return bestId
    }

    private func espnNextGame(teamId: String, sport: String, league: String) async -> GameInfo? {
        guard let url = URL(string: "\(Self.espnBase)/\(sport)/\(league)/teams/\(teamId)/schedule"),
              let data = await getJSON(url) as? [String: Any],
              let events = data["events"] as? [[String: Any]] else { return nil }
        for event in events {
            guard let comp = (event["competitions"] as? [[String:Any]])?.first else { continue }
            let state = ((comp["status"] as? [String:Any])?["type"] as? [String:Any])?["state"] as? String ?? ""
            guard state == "pre" else { continue }
            let competitors = comp["competitors"] as? [[String:Any]] ?? []
            let home = competitors.first(where: { ($0["homeAway"] as? String) == "home" }) ?? [:]
            let away = competitors.first(where: { ($0["homeAway"] as? String) == "away" }) ?? [:]
            let ht = home["team"] as? [String:Any] ?? [:]
            let at = away["team"] as? [String:Any] ?? [:]
            return GameInfo(
                homeTeam: ht["displayName"] as? String ?? "",
                awayTeam: at["displayName"] as? String ?? "",
                homeId:   ht["id"] as? String ?? "",
                awayId:   at["id"] as? String ?? "",
                venue:    (comp["venue"] as? [String:Any])?["fullName"] as? String ?? "TBD",
                dateISO:  event["date"] as? String ?? "",
                competition: (data["season"] as? [String:Any])?["displayName"] as? String ?? ""
            )
        }
        return nil
    }

    private func espnRoster(teamId: String, sport: String, league: String) async -> [RawPlayerInfo] {
        guard let url = URL(string: "\(Self.espnBase)/\(sport)/\(league)/teams/\(teamId)/roster"),
              let data = await getJSON(url) as? [String: Any],
              let athletes = data["athletes"] as? [[String:Any]] else { return [] }
        var players: [RawPlayerInfo] = []
        for item in athletes {
            if let items = item["items"] as? [[String:Any]] {
                players.append(contentsOf: items.map(parseAthlete))
            } else {
                players.append(parseAthlete(item))
            }
        }
        return players
    }

    private func espnPlayerStats(playerId: String, sport: String, league: String) async -> [String: String] {
        guard let url = URL(string: "\(Self.espnCore)/\(sport)/leagues/\(league)/athletes/\(playerId)/statistics/0"),
              let data = await getJSON(url) as? [String: Any],
              let cats = (data["splits"] as? [String:Any])?["categories"] as? [[String:Any]] else { return [:] }
        var stats: [String: String] = [:]
        for cat in cats {
            for stat in (cat["stats"] as? [[String:Any]] ?? []) {
                let name  = stat["displayName"] as? String ?? ""
                let value = stat["displayValue"] as? String ?? ""
                if !name.isEmpty && !["","0","0.0"].contains(value) { stats[name] = value }
            }
        }
        return stats
    }

    private func espnTeamNews(teamId: String, sport: String, league: String) async -> [String] {
        guard let url = URL(string: "\(Self.espnBase)/\(sport)/\(league)/news?team=\(teamId)&limit=10"),
              let data = await getJSON(url) as? [String: Any],
              let articles = data["articles"] as? [[String:Any]] else { return [] }
        return articles.compactMap { ($0["headline"] as? String)?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.prefix(6).map { $0 }
    }

    // MARK: - MLB

    private func mlbFindTeamId(_ teamName: String) async -> String? {
        guard let url = URL(string: "https://statsapi.mlb.com/api/v1/teams?sportId=1"),
              let data = await getJSON(url) as? [String: Any],
              let teams = data["teams"] as? [[String:Any]] else { return nil }
        let lower = teamName.lowercased()
        for team in teams {
            let name  = (team["name"] as? String ?? "").lowercased()
            let short = (team["teamName"] as? String ?? "").lowercased()
            if lower.contains(name) || name.contains(lower) || lower.contains(short) {
                return String(team["id"] as? Int ?? 0)
            }
        }
        return nil
    }

    private func mlbNextGame(teamId: String) async -> GameInfo? {
        guard let url = URL(string: "https://statsapi.mlb.com/api/v1/schedule/games/?sportId=1&teamId=\(teamId)"),
              let data = await getJSON(url) as? [String: Any],
              let dates = data["dates"] as? [[String:Any]], !dates.isEmpty,
              let game  = (dates[0]["games"] as? [[String:Any]])?.first else { return nil }
        let homeTeam = (game["teams"] as? [String:Any])?["home"] as? [String:Any]
        let awayTeam = (game["teams"] as? [String:Any])?["away"] as? [String:Any]
        return GameInfo(
            homeTeam: (homeTeam?["team"] as? [String:Any])?["name"] as? String ?? "",
            awayTeam: (awayTeam?["team"] as? [String:Any])?["name"] as? String ?? "",
            homeId:   String((homeTeam?["team"] as? [String:Any])?["id"] as? Int ?? 0),
            awayId:   String((awayTeam?["team"] as? [String:Any])?["id"] as? Int ?? 0),
            venue:    (game["venue"] as? [String:Any])?["name"] as? String ?? "TBD",
            dateISO:  game["gameDate"] as? String ?? "",
            competition: "MLB"
        )
    }

    private func mlbRoster(teamId: String) async -> [RawPlayerInfo] {
        guard let url = URL(string: "https://statsapi.mlb.com/api/v1/teams/\(teamId)/roster?season=2026&rosterType=active"),
              let data = await getJSON(url) as? [String: Any],
              let roster = data["roster"] as? [[String:Any]] else { return [] }
        return roster.map { entry in
            let person = entry["person"] as? [String:Any] ?? [:]
            return RawPlayerInfo(
                id:       String(person["id"] as? Int ?? 0),
                name:     person["fullName"] as? String ?? "",
                number:   Int(entry["jerseyNumber"] as? String ?? ""),
                position: (entry["position"] as? [String:Any])?["abbreviation"] as? String ?? ""
            )
        }
    }

    private func mlbPlayerStats(playerId: String) async -> [String: String] {
        for group in ["hitting","pitching"] {
            guard let url = URL(string: "https://statsapi.mlb.com/api/v1/people/\(playerId)/stats?stats=season&season=2026&group=\(group)"),
                  let data = await getJSON(url) as? [String: Any],
                  let splits = (data["stats"] as? [[String:Any]])?.first?["splits"] as? [[String:Any]],
                  !splits.isEmpty,
                  let stat = splits[0]["stat"] as? [String:Any] else { continue }
            var result: [String: String] = [:]
            for (k,v) in stat { let s = "\(v)"; if !["0","0.0",".000","","null"].contains(s) { result[k] = s } }
            if !result.isEmpty { return result }
        }
        return [:]
    }

    // MARK: - NHL

    func nhlAbbrev(_ teamName: String) -> String? {
        let lower = teamName.lowercased()
        for (key, abbrev) in Self.nhlAbbrevs { if lower.contains(key) { return abbrev } }
        return nil
    }

    private func nhlNextGame(abbrev: String) async -> GameInfo? {
        guard let url = URL(string: "https://api-web.nhle.com/v1/club-schedule-season/\(abbrev)/now"),
              let data = await getJSON(url) as? [String: Any],
              let games = data["games"] as? [[String:Any]] else { return nil }
        for game in games {
            let state = game["gameState"] as? String ?? ""
            guard ["FUT","PRE"].contains(state) else { continue }
            let home = game["homeTeam"] as? [String:Any] ?? [:]
            let away = game["awayTeam"] as? [String:Any] ?? [:]
            let hn = [home["placeName"] as? [String:Any], home["commonName"] as? [String:Any]]
                .compactMap { $0?["default"] as? String }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            let an = [away["placeName"] as? [String:Any], away["commonName"] as? [String:Any]]
                .compactMap { $0?["default"] as? String }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            return GameInfo(homeTeam: hn, awayTeam: an,
                            homeId: home["abbrev"] as? String ?? "",
                            awayId: away["abbrev"] as? String ?? "",
                            venue: (game["venue"] as? [String:Any])?["default"] as? String ?? "TBD",
                            dateISO: game["gameDate"] as? String ?? "", competition: "NHL")
        }
        return nil
    }

    private func nhlRoster(abbrev: String) async -> [RawPlayerInfo] {
        guard let url = URL(string: "https://api-web.nhle.com/v1/roster/\(abbrev)/current"),
              let data = await getJSON(url) as? [String: Any] else { return [] }
        var players: [RawPlayerInfo] = []
        for group in ["forwards","defensemen","goalies"] {
            for p in (data[group] as? [[String:Any]] ?? []) {
                let fn = (p["firstName"] as? [String:Any])?["default"] as? String ?? ""
                let ln = (p["lastName"]  as? [String:Any])?["default"] as? String ?? ""
                players.append(RawPlayerInfo(
                    id:       String(p["id"] as? Int ?? 0),
                    name:     "\(fn) \(ln)".trimmingCharacters(in: .whitespaces),
                    number:   p["sweaterNumber"] as? Int,
                    position: p["positionCode"] as? String ?? ""
                ))
            }
        }
        return players
    }

    private func nhlPlayerStats(playerId: String) async -> [String: String] {
        guard let url = URL(string: "https://api-web.nhle.com/v1/player/\(playerId)/landing"),
              let data = await getJSON(url) as? [String: Any],
              let totals = data["seasonTotals"] as? [[String:Any]], !totals.isEmpty else { return [:] }
        let latest = totals[totals.count - 1]
        var stats: [String: String] = [:]
        for key in ["goals","assists","points","plusMinus","shots","gamesPlayed","savePctg","goalsAgainstAvg","wins"] {
            if let val = latest[key], "\(val)" != "0" { stats[key] = "\(val)" }
        }
        return stats
    }

    // MARK: - Google News RSS

    private func googleNews(_ query: String, max: Int = 5) async -> [String] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://news.google.com/rss/search?q=\(encoded)&hl=en-US&gl=US&ceid=US:en"),
              let (data, resp) = try? await URLSession.shared.data(for: URLRequest(url: url)),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let xml = String(data: data, encoding: .utf8) else { return [] }
        var headlines: [String] = []
        let pattern = try! NSRegularExpression(pattern: "<title><!\\[CDATA\\[(.*?)\\]\\]></title>|<title>(.*?)</title>")
        for match in pattern.matches(in: xml, range: NSRange(xml.startIndex..., in: xml)) {
            let raw: String
            if let r = Range(match.range(at: 1), in: xml) { raw = String(xml[r]).trimmingCharacters(in: .whitespaces) }
            else if let r = Range(match.range(at: 2), in: xml) { raw = String(xml[r]).trimmingCharacters(in: .whitespaces) }
            else { continue }
            guard !raw.isEmpty, raw != "Google News" else { continue }
            let clean = raw.replacingOccurrences(of: "\\s*-\\s*[^-]+$", with: "", options: .regularExpression)
                           .trimmingCharacters(in: .whitespaces)
            if !clean.isEmpty { headlines.append(clean) }
            if headlines.count >= max { break }
        }
        return headlines
    }

    // MARK: - Helpers

    private func parseAthlete(_ a: [String:Any]) -> RawPlayerInfo {
        RawPlayerInfo(
            id:       a["id"] as? String ?? "",
            name:     a["displayName"] as? String ?? a["fullName"] as? String ?? "",
            number:   Int(a["jersey"] as? String ?? ""),
            position: (a["position"] as? [String:Any])?["abbreviation"] as? String ?? ""
        )
    }

    private func inferStatus(name: String, headlines: [String]) -> String {
        let parts = name.lowercased().split(separator: " ").filter { $0.count > 2 }.map(String.init)
        for hl in headlines {
            let h = hl.lowercased()
            guard parts.contains(where: { h.contains($0) }) else { continue }
            if h.contains("suspend")                                                          { return "suspended" }
            if h.contains("doubtful")                                                         { return "doubtful"  }
            if ["out","ruled out","injured","sidelined","misses"].contains(where: h.contains) { return "injured"   }
        }
        return "fit"
    }

    private func makeId(_ parts: String...) -> String {
        let raw = parts.filter { !$0.isEmpty }.joined(separator: "-").lowercased().trimmingCharacters(in: .whitespaces)
        let r = raw.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
                   .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return r.isEmpty ? "unknown" : r
    }

    private func getJSON(_ url: URL) async -> Any? {
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    // MARK: - Constants

    static let espnBase = "https://site.api.espn.com/apis/site/v2/sports"
    static let espnCore = "https://sports.core.api.espn.com/v2/sports"

    static let nhlAbbrevs: [String: String] = [
        "toronto":"TOR","maple leafs":"TOR","leafs":"TOR",
        "montreal":"MTL","canadiens":"MTL","boston":"BOS","bruins":"BOS",
        "new york rangers":"NYR","rangers":"NYR","edmonton":"EDM","oilers":"EDM",
        "colorado":"COL","avalanche":"COL","tampa bay":"TBL","lightning":"TBL",
        "vegas":"VGK","golden knights":"VGK","carolina":"CAR","hurricanes":"CAR",
        "florida":"FLA","panthers":"FLA","dallas":"DAL","stars":"DAL",
        "new york islanders":"NYI","islanders":"NYI","new jersey":"NJD","devils":"NJD",
        "pittsburgh":"PIT","penguins":"PIT","detroit":"DET","red wings":"DET",
        "nashville":"NSH","predators":"NSH","minnesota":"MIN","wild":"MIN",
        "winnipeg":"WPG","jets":"WPG","st. louis":"STL","blues":"STL",
        "seattle":"SEA","kraken":"SEA","chicago":"CHI","blackhawks":"CHI",
        "ottawa":"OTT","senators":"OTT","calgary":"CGY","flames":"CGY",
        "vancouver":"VAN","canucks":"VAN","buffalo":"BUF","sabres":"BUF",
        "san jose":"SJS","sharks":"SJS","philadelphia":"PHI","flyers":"PHI",
        "anaheim":"ANA","ducks":"ANA","columbus":"CBJ","washington":"WSH","capitals":"WSH",
    ]

    static let knownTeams: [String: (String, String, String)] = [
        // Soccer – PL
        "manchester city":("soccer","eng.1","Premier League"),
        "manchester united":("soccer","eng.1","Premier League"),
        "liverpool":("soccer","eng.1","Premier League"),
        "arsenal":("soccer","eng.1","Premier League"),
        "chelsea":("soccer","eng.1","Premier League"),
        "tottenham":("soccer","eng.1","Premier League"),
        "newcastle":("soccer","eng.1","Premier League"),
        "aston villa":("soccer","eng.1","Premier League"),
        // La Liga
        "real madrid":("soccer","esp.1","La Liga"),
        "barcelona":("soccer","esp.1","La Liga"),
        "atletico madrid":("soccer","esp.1","La Liga"),
        // Bundesliga
        "bayern munich":("soccer","ger.1","Bundesliga"),
        "borussia dortmund":("soccer","ger.1","Bundesliga"),
        // Serie A
        "juventus":("soccer","ita.1","Serie A"),
        "inter milan":("soccer","ita.1","Serie A"),
        "ac milan":("soccer","ita.1","Serie A"),
        "napoli":("soccer","ita.1","Serie A"),
        // Ligue 1
        "paris saint-germain":("soccer","fra.1","Ligue 1"),
        "psg":("soccer","fra.1","Ligue 1"),
        "monaco":("soccer","fra.1","Ligue 1"),
        // MLS
        "inter miami":("soccer","usa.1","MLS"),
        "la galaxy":("soccer","usa.1","MLS"),
        "lafc":("soccer","usa.1","MLS"),
        // NBA
        "los angeles lakers":("basketball","nba","NBA"),
        "lakers":("basketball","nba","NBA"),
        "golden state warriors":("basketball","nba","NBA"),
        "boston celtics":("basketball","nba","NBA"),
        "miami heat":("basketball","nba","NBA"),
        "chicago bulls":("basketball","nba","NBA"),
        "new york knicks":("basketball","nba","NBA"),
        "dallas mavericks":("basketball","nba","NBA"),
        "denver nuggets":("basketball","nba","NBA"),
        "oklahoma city thunder":("basketball","nba","NBA"),
        "cleveland cavaliers":("basketball","nba","NBA"),
        "houston rockets":("basketball","nba","NBA"),
        "indiana pacers":("basketball","nba","NBA"),
        "minnesota timberwolves":("basketball","nba","NBA"),
        // MLB
        "new york yankees":("baseball","mlb","MLB"),
        "yankees":("baseball","mlb","MLB"),
        "los angeles dodgers":("baseball","mlb","MLB"),
        "dodgers":("baseball","mlb","MLB"),
        "boston red sox":("baseball","mlb","MLB"),
        "chicago cubs":("baseball","mlb","MLB"),
        "houston astros":("baseball","mlb","MLB"),
        "atlanta braves":("baseball","mlb","MLB"),
        "new york mets":("baseball","mlb","MLB"),
        "philadelphia phillies":("baseball","mlb","MLB"),
        // NHL
        "toronto maple leafs":("hockey","nhl","NHL"),
        "leafs":("hockey","nhl","NHL"),
        "montreal canadiens":("hockey","nhl","NHL"),
        "boston bruins":("hockey","nhl","NHL"),
        "edmonton oilers":("hockey","nhl","NHL"),
        "oilers":("hockey","nhl","NHL"),
        "colorado avalanche":("hockey","nhl","NHL"),
        "tampa bay lightning":("hockey","nhl","NHL"),
        "vegas golden knights":("hockey","nhl","NHL"),
        "carolina hurricanes":("hockey","nhl","NHL"),
        "florida panthers":("hockey","nhl","NHL"),
    ]
}

// MARK: - Internal types

private struct GameInfo {
    var homeTeam: String; var awayTeam: String
    var homeId: String;   var awayId: String
    var venue: String;    var dateISO: String
    var competition: String
}

struct RawPlayerInfo {
    var id: String; var name: String; var number: Int?; var position: String
}

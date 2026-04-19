import Foundation

// MARK: - Types

struct NewsItem: Codable, Identifiable, Hashable {
    let id: String
    let headline: String
    let description: String
    let published: String
    let imageUrl: String?
    let articleUrl: String?
    let leagueKey: String
    let leagueLabel: String
    let source: NewsSource

    enum NewsSource: String, Codable {
        case espn
        case googleNews = "google_news"
    }
}

// MARK: - Service

enum NewsService {

    private struct League {
        let key: String
        let sport: String
        let league: String
        let label: String
    }

    private static let leagues: [League] = [
        League(key: "mlb",        sport: "baseball",   league: "mlb",             label: "MLB"),
        League(key: "nba",        sport: "basketball", league: "nba",             label: "NBA"),
        League(key: "wnba",       sport: "basketball", league: "wnba",            label: "WNBA"),
        League(key: "nfl",        sport: "football",   league: "nfl",             label: "NFL"),
        League(key: "ncaaf",      sport: "football",   league: "college-football",label: "NCAAF"),
        League(key: "nhl",        sport: "hockey",     league: "nhl",             label: "NHL"),
        League(key: "epl",        sport: "soccer",     league: "eng.1",           label: "EPL"),
        League(key: "laliga",     sport: "soccer",     league: "esp.1",           label: "La Liga"),
        League(key: "seriea",     sport: "soccer",     league: "ita.1",           label: "Serie A"),
        League(key: "bundesliga", sport: "soccer",     league: "ger.1",           label: "Bundesliga"),
        League(key: "ligue1",     sport: "soccer",     league: "fra.1",           label: "Ligue 1"),
        League(key: "ucl",        sport: "soccer",     league: "uefa.champions",  label: "UCL"),
        League(key: "mls",        sport: "soccer",     league: "usa.1",           label: "MLS"),
    ]

    private static let headers: [String: String] = [
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36",
        "Accept-Language": "en-US,en;q=0.9",
    ]

    // MARK: - Public API

    static func fetchLeagueNews(leagueKey: String, limit: Int = 20) async -> [NewsItem] {
        guard let league = leagues.first(where: { $0.key == leagueKey }),
              let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(league.sport)/\(league.league)/news?limit=\(limit)"),
              let data = try? await httpGet(url: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let articles = json["articles"] as? [[String: Any]] else { return [] }
        return articles.map { espnArticleToNewsItem($0, leagueKey: league.key, leagueLabel: league.label) }
    }

    static func fetchAllSportsNews(limit: Int = 10) async -> [NewsItem] {
        let mainLeagues = ["nfl", "nba", "mlb", "nhl", "epl", "mls"]
        var all: [NewsItem] = []
        await withTaskGroup(of: [NewsItem].self) { group in
            for key in mainLeagues {
                group.addTask { await fetchLeagueNews(leagueKey: key, limit: limit) }
            }
            for await items in group { all.append(contentsOf: items) }
        }
        return all.sorted {
            let df = ISO8601DateFormatter()
            let a = df.date(from: $0.published) ?? Date.distantPast
            let b = df.date(from: $1.published) ?? Date.distantPast
            return a > b
        }
    }

    static func fetchPlayerNews(playerName: String, teamName: String = "", limit: Int = 5) async -> [NewsItem] {
        let query = teamName.isEmpty ? playerName : "\(playerName) \(teamName)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://news.google.com/rss/search?q=\(encoded)&hl=en-US&gl=US&ceid=US:en"),
              let data = try? await httpGet(url: url),
              let xml = String(data: data, encoding: .utf8) else { return [] }
        return parseGoogleNewsRSS(xml: xml, limit: limit, source: .googleNews)
    }

    // MARK: - Parsing

    private static func espnArticleToNewsItem(_ a: [String: Any], leagueKey: String, leagueLabel: String) -> NewsItem {
        let id = a["id"].map { "espn-\(leagueKey)-\($0)" } ?? "espn-\(leagueKey)-\(UUID().uuidString)"
        let images = a["images"] as? [[String: Any]]
        let links  = a["links"] as? [String: Any]
        let web    = links?["web"] as? [String: Any]
        return NewsItem(
            id:          id,
            headline:    a["headline"] as? String ?? "",
            description: a["description"] as? String ?? "",
            published:   a["published"] as? String ?? ISO8601DateFormatter().string(from: Date()),
            imageUrl:    images?.first?["url"] as? String,
            articleUrl:  web?["href"] as? String,
            leagueKey:   leagueKey,
            leagueLabel: leagueLabel,
            source:      .espn
        )
    }

    private static func parseGoogleNewsRSS(xml: String, limit: Int, source: NewsItem.NewsSource) -> [NewsItem] {
        var items: [NewsItem] = []
        let pattern = try! NSRegularExpression(pattern: "<item>([\\s\\S]*?)</item>")
        let range = NSRange(xml.startIndex..., in: xml)
        for match in pattern.matches(in: xml, range: range) {
            guard let contentRange = Range(match.range(at: 1), in: xml) else { continue }
            let content = String(xml[contentRange])
            let rawTitle = extractTag(xml: content, tag: "title") ?? ""
            let headline = rawTitle.replacingOccurrences(
                of: "\\s*-\\s*[^-]+$", with: "", options: .regularExpression
            ).trimmingCharacters(in: .whitespaces)
            let description = stripHtml(extractTag(xml: content, tag: "description") ?? "")
            let published   = extractTag(xml: content, tag: "pubDate") ?? ISO8601DateFormatter().string(from: Date())
            let link        = extractTag(xml: content, tag: "link") ?? ""
            guard !headline.isEmpty, headline != "Google News" else { continue }
            let idBase = Data(link.utf8).base64EncodedString().prefix(16)
            items.append(NewsItem(
                id:          "gnews-\(idBase)",
                headline:    headline,
                description: description,
                published:   published,
                imageUrl:    nil,
                articleUrl:  link.isEmpty ? nil : link,
                leagueKey:   "player",
                leagueLabel: "Player News",
                source:      source
            ))
            if items.count >= limit { break }
        }
        return items
    }

    private static func extractTag(xml: String, tag: String) -> String? {
        let open  = "<\(tag)"
        let close = "</\(tag)>"
        guard let startRange = xml.range(of: open),
              let gtRange    = xml.range(of: ">", range: startRange.upperBound..<xml.endIndex),
              let endRange   = xml.range(of: close, range: gtRange.upperBound..<xml.endIndex) else { return nil }
        var value = String(xml[gtRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("<![CDATA[") && value.hasSuffix("]]>") {
            value = String(value.dropFirst(9).dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.isEmpty ? nil : value
    }

    private static func stripHtml(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - HTTP

    private static func httpGet(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

import Foundation
import PlayByPlayKit

/// PlayByPlayKit's public structs don't ship public memberwise inits, so
/// fixtures are built by encoding dictionaries and decoding into the public
/// Codable types. Call sites read cleaner than raw JSON literals.
enum Fixture {
    struct Athlete {
        let id: String
        let name: String
        var jersey: String? = nil
        var position: String? = nil
    }

    struct Team {
        let id: String
        let name: String?
        let abbr: String?
    }

    static func compact(
        athletes: [Athlete] = [],
        teams: [Team] = [],
        periods: [[String: Any]] = []
    ) throws -> CompactGame {
        var athleteDict: [String: [String: Any?]] = [:]
        for a in athletes {
            athleteDict[a.id] = [
                "name": a.name,
                "jersey": a.jersey as Any?,
                "position": a.position as Any?
            ]
        }
        var teamDict: [String: [String: Any?]] = [:]
        for t in teams {
            teamDict[t.id] = [
                "name": t.name as Any?,
                "abbreviation": t.abbr as Any?
            ]
        }
        let root: [String: Any] = [
            "league": [
                "key": "test",
                "sport": "soccer",
                "league": "test"
            ],
            "game": [
                "id": "g1",
                "name": "Test Match",
                "shortName": "T",
                "status": "in",
                "statusDetail": "",
                "awayTeam": "Away",
                "homeTeam": "Home",
                "awayScore": "0",
                "homeScore": "0"
            ],
            "totalPlays": 0,
            "athletes": athleteDict.mapValues(stripNulls),
            "teams": teamDict.mapValues(stripNulls),
            "periods": periods
        ]
        return try decode(root)
    }

    /// Builds a CompactPlay with the fields WhisperEngine.renderPlays consults.
    static func play(
        id: String,
        text: String,
        clock: String? = nil,
        periodNumber: Int? = nil,
        athleteId: String? = nil,
        teamId: String? = nil
    ) throws -> CompactPlay {
        var obj: [String: Any] = ["id": id, "text": text]
        if let clock { obj["clock"] = clock }
        if let periodNumber {
            obj["period"] = ["number": periodNumber]
        }
        if let athleteId {
            obj["participants"] = [["athleteId": athleteId]]
        }
        if let teamId { obj["teamId"] = teamId }
        return try decode(obj)
    }

    /// Builds a CompactGame with a single period holding the given plays,
    /// so callers can seed PlayByPlayStore.plays via `currentCompact`.
    static func compactWithPlays(_ plays: [CompactPlay]) throws -> CompactGame {
        // Re-encode the CompactPlays and drop them into a period object.
        let encoder = JSONEncoder()
        let playDicts: [[String: Any]] = try plays.map { p in
            let data = try encoder.encode(p)
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        }
        let period: [String: Any] = [
            "number": 1,
            "plays": playDicts
        ]
        return try compact(periods: [period])
    }

    // MARK: - Internals

    private static func decode<T: Decodable>(_ dict: [String: Any]) throws -> T {
        let cleaned = stripNulls(dict)
        let data = try JSONSerialization.data(withJSONObject: cleaned)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// JSONSerialization chokes on Swift `nil`; recursively drop any key whose
    /// value is Optional.none.
    private static func stripNulls(_ dict: [String: Any?]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in dict {
            guard let unwrapped = v else { continue }
            if let nested = unwrapped as? [String: Any?] {
                out[k] = stripNulls(nested)
            } else {
                out[k] = unwrapped
            }
        }
        return out
    }

    private static func stripNulls(_ dict: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in dict {
            if let nested = v as? [String: Any?] {
                out[k] = stripNulls(nested)
            } else if let nested = v as? [String: Any] {
                out[k] = stripNulls(nested)
            } else {
                out[k] = v
            }
        }
        return out
    }
}

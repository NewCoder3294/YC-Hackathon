import XCTest
@testable import PlayByPlayKit

final class CompactorTests: XCTestCase {
    private func sampleGame() -> Game {
        Game(
            id: "g1", name: "A at B", shortName: "A @ B",
            status: "In Progress", statusDetail: "Top 5th",
            homeTeam: "B", awayTeam: "A",
            homeScore: "2", awayScore: "1",
            period: "Top 5th",
            homeTeamId: "100", awayTeamId: "200",
            homeTeamAbbr: "B", awayTeamAbbr: "A"
        )
    }

    private let mlb = League(key: "mlb", sport: "baseball", league: "mlb", displayName: "MLB")

    private func rawPlays(_ json: String) throws -> [RawPlay] {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode([RawPlay].self, from: data)
    }

    func testCompactGroupsByPeriodInOrder() throws {
        let plays = try rawPlays("""
        [
          {"id":"1","period":{"number":1,"type":"Top","displayValue":"Top 1st"}},
          {"id":"2","period":{"number":1,"type":"Bot","displayValue":"Bot 1st"}},
          {"id":"3","period":{"number":2,"type":"Top","displayValue":"Top 2nd"}},
          {"id":"4","period":{"number":2,"type":"Top","displayValue":"Top 2nd"}}
        ]
        """)

        let compact = Compactor.compactGame(league: mlb, game: sampleGame(), rawPlays: plays, athleteMap: [:])

        XCTAssertEqual(compact.totalPlays, 4)
        XCTAssertEqual(compact.periods.count, 3)
        XCTAssertEqual(compact.periods[0].plays.map { $0.id }, ["1"])
        XCTAssertEqual(compact.periods[1].plays.map { $0.id }, ["2"])
        XCTAssertEqual(compact.periods[2].plays.map { $0.id }, ["3", "4"])
    }

    func testCompactPopulatesTeams() throws {
        let plays = try rawPlays("[]")
        let compact = Compactor.compactGame(league: mlb, game: sampleGame(), rawPlays: plays, athleteMap: [:])
        XCTAssertEqual(compact.teams["100"]?.name, "B")
        XCTAssertEqual(compact.teams["200"]?.name, "A")
        XCTAssertEqual(compact.teams["100"]?.abbreviation, "B")
    }

    func testCompactPopulatesAthletesFromMap() throws {
        let plays = try rawPlays("""
        [{"id":"1","participants":[{"athlete":{"$ref":"https://example.com/athletes/5?x=y"},"type":"batter"}]}]
        """)

        let map: [String: AthleteResponse] = [
            "https://example.com/athletes/5?x=y": AthleteResponse(
                id: "5",
                displayName: "Jane Doe",
                fullName: "Jane A Doe",
                jersey: "42",
                position: AthleteResponse.Position(abbreviation: "SS", displayName: "Shortstop")
            )
        ]

        let compact = Compactor.compactGame(league: mlb, game: sampleGame(), rawPlays: plays, athleteMap: map)
        XCTAssertEqual(compact.athletes["5"]?.name, "Jane Doe")
        XCTAssertEqual(compact.athletes["5"]?.jersey, "42")
        XCTAssertEqual(compact.athletes["5"]?.position, "SS")
        XCTAssertEqual(compact.periods.first?.plays.first?.participants?.first?.athleteId, "5")
    }

    func testLastCompactPlayIdWalksBackward() throws {
        let plays = try rawPlays("""
        [
          {"id":"1","period":{"number":1,"type":"Top"}},
          {"id":"2","period":{"number":2,"type":"Top"}}
        ]
        """)
        let compact = Compactor.compactGame(league: mlb, game: sampleGame(), rawPlays: plays, athleteMap: [:])
        XCTAssertEqual(Compactor.lastCompactPlayId(compact), "2")
        XCTAssertNil(Compactor.lastCompactPlayId(nil))
    }

    func testDiffNewPlaysReturnsAllWhenNoPrev() throws {
        let plays = try rawPlays("[{\"id\":\"1\"},{\"id\":\"2\"}]")
        let compact = Compactor.compactGame(league: mlb, game: sampleGame(), rawPlays: plays, athleteMap: [:])
        let delta = Compactor.diffNewPlays(prev: nil, next: compact)
        XCTAssertEqual(delta.map { $0.id }, ["1", "2"])
    }

    func testDiffNewPlaysFiltersBeforeLastId() throws {
        let prev = Compactor.compactGame(
            league: mlb, game: sampleGame(),
            rawPlays: try rawPlays("[{\"id\":\"1\"},{\"id\":\"2\"}]"),
            athleteMap: [:]
        )
        let next = Compactor.compactGame(
            league: mlb, game: sampleGame(),
            rawPlays: try rawPlays("[{\"id\":\"1\"},{\"id\":\"2\"},{\"id\":\"3\"},{\"id\":\"4\"}]"),
            athleteMap: [:]
        )
        let delta = Compactor.diffNewPlays(prev: prev, next: next)
        XCTAssertEqual(delta.map { $0.id }, ["3", "4"])
    }

    func testDiffNewPlaysReturnsAllWhenLastIdMissing() throws {
        let prev = Compactor.compactGame(
            league: mlb, game: sampleGame(),
            rawPlays: try rawPlays("[{\"id\":\"X\"}]"),
            athleteMap: [:]
        )
        let next = Compactor.compactGame(
            league: mlb, game: sampleGame(),
            rawPlays: try rawPlays("[{\"id\":\"1\"},{\"id\":\"2\"}]"),
            athleteMap: [:]
        )
        let delta = Compactor.diffNewPlays(prev: prev, next: next)
        XCTAssertEqual(delta.map { $0.id }, ["1", "2"])
    }

    func testSportFieldsEnumDispatchesCorrectly() throws {
        let nba = League(key: "nba", sport: "basketball", league: "nba", displayName: "NBA")
        let plays = try rawPlays("[{\"id\":\"1\",\"coordinate\":{\"x\":5,\"y\":5},\"pointsAttempted\":3}]")
        let compact = Compactor.compactGame(league: nba, game: sampleGame(), rawPlays: plays, athleteMap: [:])
        let first = compact.periods.first?.plays.first
        if case let .basketball(f) = first?.sportFields {
            XCTAssertEqual(f.coordinate?.x, 5)
            XCTAssertEqual(f.pointsAttempted, 3)
        } else {
            XCTFail("expected basketball sport fields")
        }
    }

    func testSportFieldsEnumRoundTrip() throws {
        let nfl = League(key: "nfl", sport: "football", league: "nfl", displayName: "NFL")
        let plays = try rawPlays("[{\"id\":\"1\",\"start\":{\"down\":1,\"distance\":10}}]")
        let compact = Compactor.compactGame(league: nfl, game: sampleGame(), rawPlays: plays, athleteMap: [:])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(compact)
        let decoded = try JSONDecoder().decode(CompactGame.self, from: data)

        if case let .football(f) = decoded.periods.first?.plays.first?.sportFields {
            XCTAssertEqual(f.start?.down, 1)
            XCTAssertEqual(f.start?.distance, 10)
        } else {
            XCTFail("expected football on round-trip")
        }
    }
}

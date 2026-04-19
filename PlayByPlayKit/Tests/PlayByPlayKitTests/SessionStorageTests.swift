import XCTest
@testable import PlayByPlayKit

final class SessionStorageTests: XCTestCase {
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlayByPlayKitTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeCompact() -> CompactGame {
        CompactGame(
            league: LeagueRef(key: "mlb", sport: "baseball", league: "mlb"),
            game: GameSummary(
                id: "g1", name: "A at B", shortName: "A @ B",
                status: "In Progress", statusDetail: "Top 5th",
                awayTeam: "A", homeTeam: "B", awayScore: "1", homeScore: "2"
            ),
            totalPlays: 2,
            athletes: ["5": Athlete(name: "Jane Doe", jersey: "42", position: "SS")],
            teams: ["100": TeamRef(name: "B", abbreviation: "B")],
            periods: [
                CompactPeriod(
                    number: 1,
                    type: "Top",
                    displayValue: "Top 1st",
                    plays: [
                        CompactPlay(id: "p1"),
                        CompactPlay(id: "p2")
                    ]
                )
            ]
        )
    }

    func testCacheFileURLFormat() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let date = ISO8601DateFormatter().date(from: "2026-04-19T10:00:00Z")!
        let url = SessionStorage.cacheFileURL(
            root: root,
            leagueKey: "mlb",
            shortName: "NYY @ BOS",
            date: date
        )
        XCTAssertEqual(url.path, "/tmp/root/mlb/NYY_@_BOS_2026-04-19.json")
    }

    func testWriteReadRoundTrip() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let compact = makeCompact()
        let url = dir.appendingPathComponent("test.json")
        try SessionStorage.write(compact, to: url)

        let loaded = try SessionStorage.read(url)
        XCTAssertEqual(loaded, compact)
    }

    func testReadReturnsNilWhenFileMissing() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("missing.json")
        XCTAssertNil(try SessionStorage.read(url))
    }

    func testWriteCreatesIntermediateDirectories() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("mlb").appendingPathComponent("game.json")
        try SessionStorage.write(makeCompact(), to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testWriteOverwritesExistingFile() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("game.json")
        try SessionStorage.write(makeCompact(), to: url)
        try SessionStorage.write(makeCompact(), to: url)  // second write should succeed
        XCTAssertNotNil(try SessionStorage.read(url))
    }
}

extension CompactPlay {
    init(id: String) {
        self.init(
            id: id, seq: nil, type: nil, text: nil,
            awayScore: nil, homeScore: nil, clock: nil,
            scoringPlay: nil, scoreValue: nil, wallclock: nil,
            teamId: nil, participants: nil, period: nil, sportFields: nil
        )
    }
}

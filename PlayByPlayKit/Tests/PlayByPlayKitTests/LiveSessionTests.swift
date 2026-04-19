import XCTest
@testable import PlayByPlayKit

final class LiveSessionTests: XCTestCase {
    private let mlb = League(key: "mlb", sport: "baseball", league: "mlb", displayName: "MLB")

    private func sampleGame() -> Game {
        Game(
            id: "401",
            name: "A at B", shortName: "A @ B",
            status: "In Progress", statusDetail: "Top 5th",
            homeTeam: "B", awayTeam: "A",
            homeScore: "0", awayScore: "0",
            period: "Top 5th",
            homeTeamId: "100", awayTeamId: "200",
            homeTeamAbbr: "B", awayTeamAbbr: "A"
        )
    }

    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlayByPlayKitTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    override func setUp() {
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
    }

    private func playsResponse(_ ids: [String]) -> Data {
        let items = ids.map { #"{"id":"\#($0)"}"# }.joined(separator: ",")
        let json = #"{"items":[\#(items)]}"#
        return json.data(using: .utf8)!
    }

    func testColdStartEmitsInitialDelta() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        MockURLProtocol.handler = { url in
            .init(statusCode: 200, body: self.playsResponse(["1", "2"]))
        }

        let session = PlayByPlay.liveSession(
            league: mlb, game: sampleGame(),
            cacheDirectory: dir,
            pollInterval: 3600,
            session: MockURLProtocol.session()
        )

        let stream = await session.deltas
        await session.start()

        var iter = stream.makeAsyncIterator()
        let delta = try await iter.next()
        XCTAssertNotNil(delta)
        XCTAssertEqual(delta?.newPlays.map { $0.id }, ["1", "2"])
        XCTAssertEqual(delta?.state.totalPlays, 2)

        await session.stop()
    }

    func testResumeSuppressesUnchangedPollThenEmitsNew() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        var callCount = 0
        MockURLProtocol.handler = { url in
            MockURLProtocol.lock.lock()
            callCount += 1
            let c = callCount
            MockURLProtocol.lock.unlock()
            if c == 1 {
                return .init(statusCode: 200, body: self.playsResponse(["1", "2"]))
            } else {
                return .init(statusCode: 200, body: self.playsResponse(["1", "2", "3"]))
            }
        }

        let session = PlayByPlay.liveSession(
            league: mlb, game: sampleGame(),
            cacheDirectory: dir,
            pollInterval: 0.05,
            session: MockURLProtocol.session()
        )

        let stream = await session.deltas
        await session.start()

        var iter = stream.makeAsyncIterator()

        let first = try await iter.next()
        XCTAssertEqual(first?.newPlays.map { $0.id }, ["1", "2"])

        let second = try await iter.next()
        XCTAssertEqual(second?.newPlays.map { $0.id }, ["3"])
        XCTAssertEqual(second?.state.totalPlays, 3)

        await session.stop()
    }

    func testPermanentErrorThrowsIntoStream() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        MockURLProtocol.handler = { _ in .init(statusCode: 404, body: Data()) }

        let session = PlayByPlay.liveSession(
            league: mlb, game: sampleGame(),
            cacheDirectory: dir,
            pollInterval: 0.05,
            session: MockURLProtocol.session()
        )
        let stream = await session.deltas
        await session.start()

        var iter = stream.makeAsyncIterator()
        do {
            _ = try await iter.next()
            XCTFail("expected error")
        } catch let error as PlayByPlayError {
            if case .http(let status, _) = error {
                XCTAssertEqual(status, 404)
            } else {
                XCTFail("expected .http(404)")
            }
        }
        await session.stop()
    }

    func testTransientErrorRetries() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        var callCount = 0
        MockURLProtocol.handler = { _ in
            MockURLProtocol.lock.lock()
            callCount += 1
            let c = callCount
            MockURLProtocol.lock.unlock()
            if c == 1 {
                return .init(statusCode: 503, body: Data())
            }
            let json = #"{"items":[{"id":"1"}]}"#
            return .init(statusCode: 200, body: json.data(using: .utf8)!)
        }

        var transientCount = 0
        let lock = NSLock()

        let session = PlayByPlay.liveSession(
            league: mlb, game: sampleGame(),
            cacheDirectory: dir,
            pollInterval: 0.05,
            onTransientError: { _ in
                lock.lock()
                transientCount += 1
                lock.unlock()
            },
            session: MockURLProtocol.session()
        )
        let stream = await session.deltas
        await session.start()
        var iter = stream.makeAsyncIterator()
        let delta = try await iter.next()
        XCTAssertEqual(delta?.newPlays.map { $0.id }, ["1"])
        lock.lock()
        XCTAssertEqual(transientCount, 1)
        lock.unlock()
        await session.stop()
    }

    func testStopEndsStreamCleanly() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        MockURLProtocol.handler = { _ in
            .init(statusCode: 200, body: self.playsResponse(["1"]))
        }
        let session = PlayByPlay.liveSession(
            league: mlb, game: sampleGame(),
            cacheDirectory: dir,
            pollInterval: 3600,
            session: MockURLProtocol.session()
        )
        let stream = await session.deltas
        await session.start()
        var iter = stream.makeAsyncIterator()
        _ = try await iter.next()
        await session.stop()
        let final = try await iter.next()
        XCTAssertNil(final, "stream should terminate after stop()")
    }
}

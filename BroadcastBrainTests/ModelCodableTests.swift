import XCTest
@testable import BroadcastBrain

final class ModelCodableTests: XCTestCase {
    func testSessionRoundTrip() throws {
        let s = Session(
            title: "Arg vs Fra 2022",
            transcript: "Messi scores",
            notes: "Di María 2014 final angle",
            statCards: [
                StatCard(
                    player: "Messi",
                    statValue: "7 goals",
                    contextLine: "This WC",
                    rawTranscript: "he scores",
                    latencyMs: 120
                )
            ],
            researchMessages: [
                ChatMessage(role: .user, content: "hi", grounded: false),
                ChatMessage(role: .assistant, content: "hello", grounded: true)
            ]
        )
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        let data = try enc.encode(s)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        let decoded = try dec.decode(Session.self, from: data)

        XCTAssertEqual(s, decoded)
    }

    func testMatchCacheDecodesBundledJSON() throws {
        let bundle = Bundle(for: Self.self)
        // The JSON is in the main app bundle, not the test bundle — load via path.
        let testBundleURL = bundle.bundleURL.deletingLastPathComponent()
        let mainAppURL = testBundleURL.appendingPathComponent("BroadcastBrain.app")
        let jsonURL = mainAppURL
            .appendingPathComponent("Contents/Resources/match_cache.json")

        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw XCTSkip("match_cache.json not in app bundle at \(jsonURL.path)")
        }

        let data = try Data(contentsOf: jsonURL)
        let cache = try JSONDecoder().decode(MatchCache.self, from: data)
        XCTAssertEqual(cache.matchId, "arg-fra-2022-wc-final")
        XCTAssertFalse(cache.players.isEmpty)
        XCTAssertFalse(cache.facts.isEmpty)
    }
}

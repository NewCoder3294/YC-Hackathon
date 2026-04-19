import XCTest
@testable import PlayByPlayKit

final class LeagueTests: XCTestCase {
    func testAllLeaguesCount() {
        XCTAssertEqual(League.all.count, 15)
    }

    func testMLBLeague() {
        let mlb = League.all.first { $0.key == "mlb" }
        XCTAssertNotNil(mlb)
        XCTAssertEqual(mlb?.sport, "baseball")
        XCTAssertEqual(mlb?.league, "mlb")
    }

    func testScoreboardURL() {
        let mlb = League.all.first { $0.key == "mlb" }!
        XCTAssertEqual(
            ESPNEndpoints.scoreboardURL(mlb).absoluteString,
            "https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard"
        )
    }

    func testPlayByPlayURL() {
        let epl = League.all.first { $0.key == "epl" }!
        XCTAssertEqual(
            ESPNEndpoints.playByPlayURL(epl, gameId: "12345").absoluteString,
            "https://sports.core.api.espn.com/v2/sports/soccer/leagues/eng.1/events/12345/competitions/12345/plays?limit=1000"
        )
    }

    func testExtractIdFromRef() {
        XCTAssertEqual(ESPNRef.extractId(from: "https://example.com/v2/sports/x/athletes/33333?lang=en"), "33333")
        XCTAssertEqual(ESPNRef.extractId(from: "/teams/17"), "17")
        XCTAssertNil(ESPNRef.extractId(from: nil))
        XCTAssertNil(ESPNRef.extractId(from: "no-match-here"))
    }
}

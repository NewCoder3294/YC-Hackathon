import XCTest
@testable import PlayByPlayKit

final class ScoreboardTests: XCTestCase {
    func testDecodeAndToGames() throws {
        let json = """
        {
          "events": [
            {
              "id": "401570000",
              "name": "New York Yankees at Boston Red Sox",
              "shortName": "NYY @ BOS",
              "competitions": [
                {
                  "competitors": [
                    {
                      "id": "10",
                      "homeAway": "home",
                      "score": "3",
                      "team": { "displayName": "Boston Red Sox", "abbreviation": "BOS" }
                    },
                    {
                      "id": "9",
                      "homeAway": "away",
                      "score": "2",
                      "team": { "displayName": "New York Yankees", "abbreviation": "NYY" }
                    }
                  ],
                  "status": {
                    "type": { "description": "In Progress", "detail": "Top 7th" }
                  }
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ScoreboardResponse.self, from: json)
        let games = Scoreboard.toGames(response)
        XCTAssertEqual(games.count, 1)
        let g = games[0]
        XCTAssertEqual(g.id, "401570000")
        XCTAssertEqual(g.homeTeam, "Boston Red Sox")
        XCTAssertEqual(g.awayTeam, "New York Yankees")
        XCTAssertEqual(g.homeScore, "3")
        XCTAssertEqual(g.awayScore, "2")
        XCTAssertEqual(g.homeTeamId, "10")
        XCTAssertEqual(g.awayTeamId, "9")
        XCTAssertEqual(g.homeTeamAbbr, "BOS")
        XCTAssertEqual(g.status, "In Progress")
        XCTAssertEqual(g.statusDetail, "Top 7th")
    }

    func testEmptyScoreboard() throws {
        let json = #"{"events":[]}"#.data(using: .utf8)!
        let response = try JSONDecoder().decode(ScoreboardResponse.self, from: json)
        XCTAssertEqual(Scoreboard.toGames(response).count, 0)
    }
}

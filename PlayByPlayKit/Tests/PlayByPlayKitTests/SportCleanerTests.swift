import XCTest
@testable import PlayByPlayKit

final class SportCleanerTests: XCTestCase {
    func testBaseballCleanerPassesThroughFields() throws {
        let json = """
        {
          "id": "p1",
          "pitchCoordinate": {"x": 1.0, "y": 2.0},
          "pitchType": {"text": "Fastball"},
          "pitchVelocity": 95.5,
          "bats": {"abbreviation": "L"},
          "pitchCount": {"balls": 2, "strikes": 1},
          "outs": 1,
          "doublePlay": true,
          "homeHits": 5
        }
        """.data(using: .utf8)!
        let raw = try JSONDecoder().decode(RawPlay.self, from: json)
        let f = SportCleaners.cleanBaseball(raw)
        XCTAssertEqual(f.pitchCoordinate?.x, 1.0)
        XCTAssertEqual(f.pitchType, "Fastball")
        XCTAssertEqual(f.pitchVelocity, 95.5)
        XCTAssertEqual(f.bats, "L")
        XCTAssertEqual(f.pitchCount?.balls, 2)
        XCTAssertEqual(f.pitchCount?.strikes, 1)
        XCTAssertEqual(f.outs, 1)
        XCTAssertEqual(f.doublePlay, true)
        XCTAssertEqual(f.homeHits, 5)
    }

    func testBasketballCleanerDropsSentinel() throws {
        let json = """
        {
          "id": "p2",
          "coordinate": {"x": -214748340, "y": -214748365},
          "pointsAttempted": 3,
          "shootingPlay": true
        }
        """.data(using: .utf8)!
        let raw = try JSONDecoder().decode(RawPlay.self, from: json)
        let f = SportCleaners.cleanBasketball(raw)
        XCTAssertNil(f.coordinate, "sentinel coordinate must be dropped")
        XCTAssertEqual(f.pointsAttempted, 3)
        XCTAssertEqual(f.shootingPlay, true)
    }

    func testBasketballCleanerKeepsRealCoordinate() throws {
        let json = """
        {"id":"p3","coordinate":{"x":12.5,"y":-7.3}}
        """.data(using: .utf8)!
        let raw = try JSONDecoder().decode(RawPlay.self, from: json)
        let f = SportCleaners.cleanBasketball(raw)
        XCTAssertEqual(f.coordinate?.x, 12.5)
        XCTAssertEqual(f.coordinate?.y, -7.3)
    }

    func testFootballCleanerBuildsDriveMarkers() throws {
        let json = """
        {
          "id": "p4",
          "start": {
            "down": 3,
            "distance": 7,
            "yardLine": 45,
            "yardsToEndzone": 55,
            "team": {"$ref": "https://example.com/teams/17?lang=en"}
          },
          "end": {
            "down": 4,
            "distance": 1,
            "shortDownDistanceText": "4th & 1",
            "possessionText": "NE 46"
          },
          "statYardage": 6,
          "teamParticipants": [
            {"id": "17", "order": 1, "type": "offense"}
          ]
        }
        """.data(using: .utf8)!
        let raw = try JSONDecoder().decode(RawPlay.self, from: json)
        let f = SportCleaners.cleanFootball(raw)
        XCTAssertEqual(f.start?.down, 3)
        XCTAssertEqual(f.start?.distance, 7)
        XCTAssertEqual(f.start?.teamId, "17")
        XCTAssertEqual(f.end?.downDistance, "4th & 1")
        XCTAssertEqual(f.end?.possession, "NE 46")
        XCTAssertEqual(f.statYardage, 6)
        XCTAssertEqual(f.teamParticipants?.first?.teamId, "17")
        XCTAssertEqual(f.teamParticipants?.first?.order, 1)
    }

    func testHockeyCleaner() throws {
        let json = """
        {"id":"p5","strength":{"text":"Power Play"},"isPenalty":true,"shootingPlay":true}
        """.data(using: .utf8)!
        let raw = try JSONDecoder().decode(RawPlay.self, from: json)
        let f = SportCleaners.cleanHockey(raw)
        XCTAssertEqual(f.strength, "Power Play")
        XCTAssertEqual(f.isPenalty, true)
        XCTAssertEqual(f.shootingPlay, true)
    }

    func testSoccerCleaner() throws {
        let json = """
        {
          "id": "p6",
          "redCard": true,
          "addedClock": {"value": 5.0},
          "fieldPositionX": 12.3,
          "fieldPositionY": 45.6,
          "goalPositionX": 1.0,
          "goalPositionY": 2.0,
          "goalPositionZ": 3.0
        }
        """.data(using: .utf8)!
        let raw = try JSONDecoder().decode(RawPlay.self, from: json)
        let f = SportCleaners.cleanSoccer(raw)
        XCTAssertEqual(f.redCard, true)
        XCTAssertEqual(f.addedClock, 5.0)
        XCTAssertEqual(f.fieldPosition?.x, 12.3)
        XCTAssertEqual(f.fieldPosition?.y, 45.6)
        XCTAssertEqual(f.goalPosition?.z, 3.0)
    }
}

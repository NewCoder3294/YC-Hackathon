import XCTest
@testable import BroadcastBrain

final class MockResponderTests: XCTestCase {
    func testMatchesMessiPenalty() async throws {
        let m = MockResponder()
        let reply = try await m.complete(system: "", user: "Messi steps up for the penalty")
        XCTAssertTrue(reply.contains("Messi"), "Expected Messi in reply, got: \(reply)")
        XCTAssertTrue(reply.contains("23"), "Expected 23 in reply, got: \(reply)")
    }

    func testMatchesMbappeBrace() async throws {
        let m = MockResponder()
        let reply = try await m.complete(system: "", user: "Mbappé just scored his second")
        XCTAssertTrue(reply.contains("Mbappé"))
        XCTAssertTrue(reply.contains("80") && reply.contains("81"))
    }

    func testReturnsNoDataWhenUnmatched() async throws {
        let m = MockResponder()
        let reply = try await m.complete(system: "", user: "completely unrelated sentence about the weather")
        XCTAssertTrue(reply.contains("no_verified_data"), "Expected no_verified_data, got: \(reply)")
    }

    func testResearchModeReturnsProse() async throws {
        let m = MockResponder()
        let reply = try await m.complete(
            system: "You are a research assistant. Q&A grounded on facts.",
            user: "How many WC goals does Mbappé have?"
        )
        XCTAssertTrue(reply.contains("12"), "Expected career goals total 12, got: \(reply)")
        XCTAssertFalse(reply.contains("no_verified_data"))
    }
}

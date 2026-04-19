import XCTest
@testable import BroadcastBrain

/// Real Cactus service is an integration test. It requires the Gemma model
/// weights to be present on disk. Skipped if missing.
final class CactusServiceTests: XCTestCase {
    func testHelloWorldCompletion() async throws {
        let modelURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BroadcastBrain/models/gemma.gguf")

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw XCTSkip("Gemma model not present at \(modelURL.path); download weights to run this test.")
        }

        let service = try RealCactusService(modelPath: modelURL.path)
        let reply = try await service.complete(
            system: "You are a test harness. Reply with exactly the single word: READY.",
            user: "Ping"
        )
        XCTAssertFalse(reply.isEmpty, "Empty reply from Gemma")
        print("Gemma reply:", reply)
    }
}

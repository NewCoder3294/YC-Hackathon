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

    // MARK: - extractContent envelope cases
    //
    // Cactus has shipped at least three envelope shapes for chat completions.
    // If any of these regress, WhisperEngine.parseWhisper sees the raw wrapper
    // JSON, fails to extract {"answer":...} and silently drops every tick.

    func testExtractContentOpenAIEnvelope() {
        let raw = #"{"choices":[{"message":{"content":"hello world"}}]}"#
        XCTAssertEqual(RealCactusService.extractContent(from: raw), "hello world")
    }

    func testExtractContentLegacyContentKey() {
        let raw = #"{"content":"hello"}"#
        XCTAssertEqual(RealCactusService.extractContent(from: raw), "hello")
    }

    func testExtractContentFFIResponseEnvelope() {
        let raw = #"{"success":true,"response":"hello","usage":{"tokens":10}}"#
        XCTAssertEqual(RealCactusService.extractContent(from: raw), "hello")
    }

    func testExtractContentFFIResponseSurfacesEvenWhenSuccessFalse() {
        // extractContent should still surface partial text; callers log the parse fail.
        let raw = #"{"success":false,"response":"partial text"}"#
        XCTAssertEqual(RealCactusService.extractContent(from: raw), "partial text")
    }

    func testExtractContentRawStringPassThrough() {
        let raw = "not json at all"
        XCTAssertEqual(RealCactusService.extractContent(from: raw), "not json at all")
    }

    func testExtractContentStripsJSONFence() {
        let raw = """
        {"response":"```json\\n{\\"answer\\":\\"yes\\"}\\n```"}
        """
        XCTAssertEqual(RealCactusService.extractContent(from: raw), #"{"answer":"yes"}"#)
    }

    func testStripCodeFencesRemovesJSONLabel() {
        let input = "```json\n{\"a\":1}\n```"
        XCTAssertEqual(RealCactusService.stripCodeFences(input), #"{"a":1}"#)
    }

    func testStripCodeFencesRemovesBareFence() {
        let input = "```\nplain\n```"
        XCTAssertEqual(RealCactusService.stripCodeFences(input), "plain")
    }

    func testStripCodeFencesNoopWhenAbsent() {
        let input = "no fences here"
        XCTAssertEqual(RealCactusService.stripCodeFences(input), "no fences here")
    }

    func testStripCodeFencesLeavesInteriorBackticksAlone() {
        let input = "inline `code` sample"
        XCTAssertEqual(RealCactusService.stripCodeFences(input), "inline `code` sample")
    }
}

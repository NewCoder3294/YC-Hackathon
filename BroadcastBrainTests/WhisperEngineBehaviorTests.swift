import XCTest
import PlayByPlayKit
@testable import BroadcastBrain

/// End-to-end behavior of WhisperEngine.triggerOnce — the path the autonomous
/// 30-second tick actually takes — with a fake Cactus and a spy TTS so we can
/// assert which prompt was sent, what was appended, and whether we spoke.
@MainActor
final class WhisperEngineBehaviorTests: XCTestCase {

    // MARK: - Fakes

    /// Fake Cactus. Programmable response per-call + records the (system, user)
    /// pair so tests can assert prompt shape.
    final class FakeCactus: CactusService {
        enum Outcome {
            case reply(String)
            case throwError(Error)
        }
        var outcomes: [Outcome] = []
        private(set) var calls: [(system: String, user: String)] = []

        func complete(system: String, user: String) async throws -> String {
            calls.append((system, user))
            guard !outcomes.isEmpty else {
                XCTFail("FakeCactus.complete called with no outcomes queued")
                return ""
            }
            switch outcomes.removeFirst() {
            case .reply(let s): return s
            case .throwError(let e): throw e
            }
        }
    }

    /// Spy TTS — records calls without touching AVSpeechSynthesizer.
    final class SpeechSpy: SpeechSynthesizing {
        var isSpeaking: Bool = false
        private(set) var speakCalls: [String] = []
        private(set) var stopCallCount = 0

        func speak(_ text: String) { speakCalls.append(text) }
        func stop() { stopCallCount += 1 }
    }

    struct FakeError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: - Harness

    struct Harness {
        let appStore: AppStore
        let engine: WhisperEngine
        let cactus: FakeCactus
        let speech: SpeechSpy
        let tmpDir: URL
    }

    private var harnesses: [Harness] = []

    override func tearDown() {
        for h in harnesses {
            try? FileManager.default.removeItem(at: h.tmpDir)
        }
        harnesses.removeAll()
        super.tearDown()
    }

    @MainActor
    private func makeHarness() -> Harness {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BBWhisper-\(UUID())", isDirectory: true)
        let sessionStore = SessionStore(storageDir: tmp)
        let cactus = FakeCactus()
        let speech = SpeechSpy()
        let pbp = PlayByPlayStore(cacheDirectory: tmp.appendingPathComponent("pbp"))
        let engine = WhisperEngine(cactus: cactus, tts: speech)
        let app = AppStore(
            sessionStore: sessionStore,
            cactus: cactus,
            playByPlayStore: pbp,
            speech: SpeechSynthesisService(), // AppStore still uses the concrete one
            whisperEngine: engine
        )
        // AppStore.init calls engine.attach(store: self) — so triggerOnce below
        // reads the session + plays off this same AppStore instance.
        let h = Harness(
            appStore: app,
            engine: engine,
            cactus: cactus,
            speech: speech,
            tmpDir: tmp
        )
        harnesses.append(h)
        return h
    }

    @MainActor
    private func seedPlay(_ h: Harness, text: String = "scores") {
        do {
            let play = try Fixture.play(
                id: UUID().uuidString,
                text: text,
                clock: "45'",
                periodNumber: 1
            )
            let compact = try Fixture.compactWithPlays([play])
            h.appStore.playByPlayStore.currentCompact = compact
        } catch {
            XCTFail("seedPlay failed: \(error)")
        }
    }

    // MARK: - triggerOnce behavior

    func testTriggerOnceSkipsWhenNoPlays() async {
        let h = makeHarness()
        // Intentionally do not seed plays.
        let beforeCount = h.appStore.currentSession.statCards.count

        await h.engine.triggerOnce()

        XCTAssertEqual(h.cactus.calls.count, 0, "Must not call Cactus when feed is empty")
        XCTAssertEqual(h.appStore.currentSession.statCards.count, beforeCount)
        XCTAssertEqual(h.speech.speakCalls.count, 0)
        XCTAssertNil(h.appStore.inferenceWarning)
    }

    func testTriggerOnceAppendsCardAndSpeaksOnValidWhisper() async {
        let h = makeHarness()
        seedPlay(h, text: "Messi scores")
        h.cactus.outcomes = [.reply(
            #"{"type":"whisper","player":"Messi","answer":"Messi has 3 shots on target.","source":"ESPN play-by-play"}"#
        )]

        await h.engine.triggerOnce()

        XCTAssertEqual(h.cactus.calls.count, 1)
        let added = h.appStore.currentSession.statCards.last
        XCTAssertNotNil(added, "Expected a StatCard to be appended")
        XCTAssertEqual(added?.kind, .whisper)
        XCTAssertEqual(added?.player, "Messi")
        XCTAssertEqual(added?.answer, "Messi has 3 shots on target.")
        XCTAssertEqual(added?.rawTranscript, "", "auto-whisper marker")
        XCTAssertEqual(h.speech.speakCalls, ["Messi has 3 shots on target."])
        XCTAssertNotNil(h.appStore.lastLatencyMs)
        XCTAssertNil(h.appStore.inferenceWarning)
    }

    func testTriggerOnceSendsPromptWithMatchLeagueAndPlays() async {
        let h = makeHarness()
        seedPlay(h, text: "Di María crosses")
        h.cactus.outcomes = [.reply(#"{"no_verified_data":true}"#)] // shape-only test

        await h.engine.triggerOnce()

        guard let call = h.cactus.calls.first else { return XCTFail("no call captured") }
        XCTAssertTrue(call.system.contains("live broadcast stats whisperer"),
                      "system prompt changed — tests must be updated")
        XCTAssertTrue(call.user.contains("Match:"))
        XCTAssertTrue(call.user.contains("League:"))
        XCTAssertTrue(call.user.contains("plays"))
        XCTAssertTrue(call.user.contains("Di María crosses"),
                      "the seeded play must appear in the user prompt")
    }

    func testTriggerOnceDoesNotAppendOnNoVerifiedData() async {
        let h = makeHarness()
        seedPlay(h)
        h.cactus.outcomes = [.reply(#"{"no_verified_data":true}"#)]
        let before = h.appStore.currentSession.statCards.count

        await h.engine.triggerOnce()

        XCTAssertEqual(h.appStore.currentSession.statCards.count, before)
        XCTAssertEqual(h.speech.speakCalls.count, 0)
        XCTAssertNil(h.appStore.inferenceWarning, "no_verified_data is expected, not an error")
    }

    func testTriggerOnceDoesNotAppendOnUnparseable() async {
        let h = makeHarness()
        seedPlay(h)
        h.cactus.outcomes = [.reply("total garbage, no json anywhere")]
        let before = h.appStore.currentSession.statCards.count

        await h.engine.triggerOnce()

        XCTAssertEqual(h.appStore.currentSession.statCards.count, before)
        XCTAssertEqual(h.speech.speakCalls.count, 0)
    }

    func testTriggerOnceDoesNotAppendOnEmptyAnswer() async {
        let h = makeHarness()
        seedPlay(h)
        h.cactus.outcomes = [.reply(#"{"player":"Messi","answer":""}"#)]
        let before = h.appStore.currentSession.statCards.count

        await h.engine.triggerOnce()

        XCTAssertEqual(h.appStore.currentSession.statCards.count, before)
        XCTAssertEqual(h.speech.speakCalls.count, 0)
    }

    func testTriggerOnceSetsWarningAndSkipsOnCactusError() async {
        let h = makeHarness()
        seedPlay(h)
        h.cactus.outcomes = [.throwError(FakeError(message: "runtime boom"))]
        let before = h.appStore.currentSession.statCards.count

        await h.engine.triggerOnce()

        XCTAssertEqual(h.appStore.currentSession.statCards.count, before)
        XCTAssertEqual(h.speech.speakCalls.count, 0)
        XCTAssertNotNil(h.appStore.inferenceWarning)
        XCTAssertTrue(h.appStore.inferenceWarning?.contains("runtime boom") ?? false,
                      "warning should surface the underlying error message")
    }

    func testTriggerOnceTolerantOfGemmaChatterAroundJSON() async {
        let h = makeHarness()
        seedPlay(h)
        h.cactus.outcomes = [.reply(
            "sure, here's a stat:\n{\"player\":\"Mbappé\",\"answer\":\"2 goals in the final.\"}\nhope it helps"
        )]

        await h.engine.triggerOnce()

        let added = h.appStore.currentSession.statCards.last
        XCTAssertEqual(added?.player, "Mbappé")
        XCTAssertEqual(added?.answer, "2 goals in the final.")
        XCTAssertEqual(h.speech.speakCalls, ["2 goals in the final."])
    }

    func testTriggerOnceIncludesTranscriptTailInPrompt() async {
        let h = makeHarness()
        seedPlay(h)
        h.appStore.appendTranscript("first line")
        h.appStore.appendTranscript("second line")
        h.cactus.outcomes = [.reply(#"{"no_verified_data":true}"#)]

        await h.engine.triggerOnce()

        guard let call = h.cactus.calls.first else { return XCTFail("no call") }
        XCTAssertTrue(call.user.contains("first line"))
        XCTAssertTrue(call.user.contains("second line"))
    }

    // MARK: - Lifecycle

    func testStartSetsIsRunning() {
        let h = makeHarness()
        XCTAssertFalse(h.engine.isRunning)
        h.engine.start()
        XCTAssertTrue(h.engine.isRunning)
        h.engine.stop()
        XCTAssertFalse(h.engine.isRunning)
    }

    func testStartIsIdempotent() {
        let h = makeHarness()
        h.engine.start()
        h.engine.start() // second call must be a no-op, not double-schedule
        XCTAssertTrue(h.engine.isRunning)
        h.engine.stop()
    }

    func testStopWithoutStartIsSafe() {
        let h = makeHarness()
        h.engine.stop() // must not crash or flip isRunning
        XCTAssertFalse(h.engine.isRunning)
    }

    func testStopStopsTTS() {
        let h = makeHarness()
        h.engine.start()
        h.engine.stop()
        XCTAssertGreaterThanOrEqual(h.speech.stopCallCount, 1,
                                    "stop() must quiet any in-flight TTS")
    }
}

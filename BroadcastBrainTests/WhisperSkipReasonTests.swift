import XCTest
import PlayByPlayKit
@testable import BroadcastBrain

/// Pins the contract for `AppStore.lastWhisperSkip` — the observable signal
/// the UI uses to show "armed but waiting on feed" vs "armed but Gemma
/// refused" vs "armed but Cactus errored."
///
/// Before this, every skip produced a debug log and nothing else on the
/// store, so the teammate running the app had no way to tell the cases
/// apart. Phase 3 surfaces each case; this file locks in the mapping.
@MainActor
final class WhisperSkipReasonTests: XCTestCase {

    typealias FakeCactus = WhisperEngineBehaviorTests.FakeCactus
    typealias SpeechSpy = WhisperEngineBehaviorTests.SpeechSpy

    private var tmpDirs: [URL] = []

    override func tearDown() {
        for d in tmpDirs { try? FileManager.default.removeItem(at: d) }
        tmpDirs.removeAll()
        super.tearDown()
    }

    private func makeEnv(cactus: CactusService) -> (AppStore, WhisperEngine) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BBSkip-\(UUID())", isDirectory: true)
        tmpDirs.append(tmp)
        let engine = WhisperEngine(cactus: cactus, tts: SpeechSpy())
        let app = AppStore(
            sessionStore: SessionStore(storageDir: tmp),
            cactus: cactus,
            playByPlayStore: PlayByPlayStore(cacheDirectory: tmp.appendingPathComponent("pbp")),
            speech: SpeechSynthesisService(),
            whisperEngine: engine
        )
        return (app, engine)
    }

    private func seedPlay(_ app: AppStore) {
        do {
            let play = try Fixture.play(
                id: UUID().uuidString,
                text: "Messi scores",
                clock: "45'",
                periodNumber: 1
            )
            app.playByPlayStore.currentCompact = try Fixture.compactWithPlays([play])
        } catch { XCTFail("seedPlay: \(error)") }
    }

    // MARK: - Skip reasons

    func testNoPlaysSetsNoPlays() async {
        let cactus = FakeCactus()
        let (app, engine) = makeEnv(cactus: cactus)
        // no plays seeded
        await engine.triggerOnce()
        XCTAssertEqual(app.lastWhisperSkip, .noPlays)
        XCTAssertEqual(cactus.calls.count, 0)
    }

    func testNoVerifiedDataSetsNoVerifiedData() async {
        let cactus = FakeCactus()
        cactus.outcomes = [.reply(#"{"no_verified_data":true}"#)]
        let (app, engine) = makeEnv(cactus: cactus)
        seedPlay(app)
        await engine.triggerOnce()
        XCTAssertEqual(app.lastWhisperSkip, .noVerifiedData)
    }

    func testEmptyAnswerSetsEmptyAnswer() async {
        let cactus = FakeCactus()
        cactus.outcomes = [.reply(#"{"player":"Messi","answer":""}"#)]
        let (app, engine) = makeEnv(cactus: cactus)
        seedPlay(app)
        await engine.triggerOnce()
        XCTAssertEqual(app.lastWhisperSkip, .emptyAnswer)
    }

    func testUnparseableSetsUnparseable() async {
        let cactus = FakeCactus()
        cactus.outcomes = [.reply("just prose no json")]
        let (app, engine) = makeEnv(cactus: cactus)
        seedPlay(app)
        await engine.triggerOnce()
        XCTAssertEqual(app.lastWhisperSkip, .unparseable)
    }

    func testCactusErrorSetsCactusError() async {
        struct BoomError: Error, LocalizedError {
            var errorDescription: String? { "runtime boom" }
        }
        let cactus = FakeCactus()
        cactus.outcomes = [.throwError(BoomError())]
        let (app, engine) = makeEnv(cactus: cactus)
        seedPlay(app)
        await engine.triggerOnce()
        if case .cactusError(let msg) = app.lastWhisperSkip {
            XCTAssertTrue(msg.contains("runtime boom"))
        } else {
            XCTFail("expected .cactusError, got \(String(describing: app.lastWhisperSkip))")
        }
    }

    // MARK: - Clearing

    func testSuccessfulCardClearsSkipReason() async {
        let cactus = FakeCactus()
        // Tick 1: no-plays → skip set
        let (app, engine) = makeEnv(cactus: cactus)
        await engine.triggerOnce()
        XCTAssertEqual(app.lastWhisperSkip, .noPlays)

        // Tick 2: plays + valid answer → skip cleared
        seedPlay(app)
        cactus.outcomes = [.reply(
            #"{"player":"Messi","answer":"Messi has 3 shots on target.","source":"ESPN"}"#
        )]
        await engine.triggerOnce()
        XCTAssertNil(app.lastWhisperSkip, "successful card must clear the skip reason")
    }

    // MARK: - displayText (dev-tool labels)

    func testDisplayTextForEachCase() {
        XCTAssertEqual(WhisperSkipReason.noPlays.displayText, "waiting on live feed")
        XCTAssertEqual(WhisperSkipReason.noVerifiedData.displayText, "no grounded stat this tick")
        XCTAssertEqual(WhisperSkipReason.emptyAnswer.displayText, "Gemma returned empty answer")
        XCTAssertEqual(WhisperSkipReason.unparseable.displayText, "Gemma reply had no JSON")
        XCTAssertEqual(
            WhisperSkipReason.cactusError(message: "boom").displayText,
            "Cactus error: boom"
        )
    }

    // MARK: - CactusService source labels

    func testUnavailableCactusReportsUnavailable() {
        let u = UnavailableCactusService(reason: "missing weights")
        XCTAssertEqual(u.sourceLabel, "UNAVAILABLE")
        XCTAssertFalse(u.isHealthy)
    }

    func testFakeCactusReportsFakeAndHealthy() {
        let f = FakeCactus()
        XCTAssertEqual(f.sourceLabel, "FAKE")
        XCTAssertTrue(f.isHealthy)
    }
}

import XCTest
import PlayByPlayKit
@testable import BroadcastBrain

/// Symptom-driven diagnostic suite. Each test reproduces a specific
/// "agent appears to not be working" scenario and asserts the observable
/// side effects that distinguish that scenario from the others.
///
/// Use this file as a decision table when someone reports "whisper is
/// broken." Identify which test's outputs match the observed app state;
/// that's your failure mode.
///
/// | Scenario                       | cactus called | card added | warning set | speaks |
/// | ------------------------------ | ------------- | ---------- | ----------- | ------ |
/// | A. no live feed attached       | NO            | no         | nil         | no     |
/// | B. cactus unavailable          | YES (throws)  | no         | YES         | no     |
/// | C. gemma returns no_verified   | YES           | no         | nil         | no     |
/// | D. gemma returns prose         | YES           | no         | nil         | no     |
/// | E. healthy path                | YES           | YES        | nil         | YES    |
@MainActor
final class WhisperEngineDiagnosticTests: XCTestCase {

    // Reuse the fakes from the behavior suite.
    typealias FakeCactus = WhisperEngineBehaviorTests.FakeCactus
    typealias SpeechSpy = WhisperEngineBehaviorTests.SpeechSpy

    private var tmpDirs: [URL] = []

    override func tearDown() {
        for d in tmpDirs { try? FileManager.default.removeItem(at: d) }
        tmpDirs.removeAll()
        super.tearDown()
    }

    private func makeEnv(cactus: CactusService) -> (AppStore, WhisperEngine, SpeechSpy) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("BBDiag-\(UUID())", isDirectory: true)
        tmpDirs.append(tmp)
        let sessionStore = SessionStore(storageDir: tmp)
        let speech = SpeechSpy()
        let pbp = PlayByPlayStore(cacheDirectory: tmp.appendingPathComponent("pbp"))
        let engine = WhisperEngine(cactus: cactus, tts: speech)
        let app = AppStore(
            sessionStore: sessionStore,
            cactus: cactus,
            playByPlayStore: pbp,
            speech: SpeechSynthesisService(),
            whisperEngine: engine
        )
        return (app, engine, speech)
    }

    private func seedPlay(_ app: AppStore, text: String = "Messi scores") {
        do {
            let play = try Fixture.play(
                id: UUID().uuidString,
                text: text,
                clock: "45'",
                periodNumber: 1
            )
            app.playByPlayStore.currentCompact = try Fixture.compactWithPlays([play])
        } catch {
            XCTFail("seedPlay failed: \(error)")
        }
    }

    // MARK: - Scenario A: the default hackathon session has no live feed
    //
    // Match.sampleArgFra2022 — the seeded session used on every cold launch —
    // has nil leagueKey and gameId, so AppStore.startPlayByPlayIfNeeded is a
    // no-op and PlayByPlayStore.plays stays empty. Every WhisperEngine tick
    // bails at `guard !plays.isEmpty`. UI shows "AGENT · 30s" active but no
    // cards appear and no warning is surfaced.

    func testScenarioA_defaultSessionProducesNothing() async {
        let cactus = FakeCactus()
        let (app, engine, speech) = makeEnv(cactus: cactus)

        XCTAssertEqual(app.currentSession.match?.title, Match.sampleArgFra2022.title,
                       "default seeded session should be the Arg/Fra fixture")
        XCTAssertNil(app.currentSession.match?.leagueKey,
                     "the seeded match has no ESPN league bound — this is why no feed starts")
        XCTAssertNil(app.currentSession.match?.gameId)
        XCTAssertTrue(app.playByPlayStore.plays.isEmpty,
                      "no feed attached → no plays")

        let cardsBefore = app.currentSession.statCards.count
        await engine.triggerOnce()

        XCTAssertEqual(cactus.calls.count, 0,
                       "ScenarioA fingerprint: Cactus is never called")
        XCTAssertEqual(app.currentSession.statCards.count, cardsBefore)
        XCTAssertEqual(speech.speakCalls.count, 0)
        XCTAssertNil(app.inferenceWarning,
                     "ScenarioA is silent — no warning is surfaced today (fix candidate)")
    }

    // MARK: - Scenario B: Cactus is UnavailableCactusService
    //
    // Happens when Gemma weights are missing or init failed. AppStore already
    // sets an initial inferenceWarning in that case. Every tick then throws
    // CactusError.initFailed, which WhisperEngine catches and surfaces.

    func testScenarioB_cactusUnavailableSetsWarning() async {
        let unavailable = UnavailableCactusService(reason: "gemma.gguf missing")
        let (app, engine, speech) = makeEnv(cactus: unavailable)
        seedPlay(app) // feed IS attached — isolates the cactus failure

        // AppStore seeds its own warning when cactus is unavailable.
        XCTAssertNotNil(app.inferenceWarning,
                        "AppStore should pre-flag missing Gemma on init")

        app.inferenceWarning = nil // reset to observe tick-driven update
        await engine.triggerOnce()

        XCTAssertEqual(app.currentSession.statCards.count, 0)
        XCTAssertEqual(speech.speakCalls.count, 0)
        XCTAssertNotNil(app.inferenceWarning,
                        "ScenarioB fingerprint: tick surfaces a warning every call")
        XCTAssertTrue(app.inferenceWarning?.contains("gemma.gguf missing") ?? false,
                      "warning should mention the underlying reason")
    }

    // MARK: - Scenario C: Gemma returns no_verified_data every tick
    //
    // Happens when the prompt is too restrictive or plays are too sparse for
    // Gemma-1B to ground an answer. User sees: agent running, feed attached,
    // still no cards. Only a debug log — the UI gives zero feedback.

    func testScenarioC_geminaRefusesToGroundEveryTick() async {
        let cactus = FakeCactus()
        cactus.outcomes = Array(repeating: .reply(#"{"no_verified_data":true}"#), count: 3)
        let (app, engine, speech) = makeEnv(cactus: cactus)
        seedPlay(app)

        await engine.triggerOnce()
        await engine.triggerOnce()
        await engine.triggerOnce()

        XCTAssertEqual(cactus.calls.count, 3, "ScenarioC: cactus IS called each tick")
        XCTAssertEqual(app.currentSession.statCards.count, 0,
                       "ScenarioC fingerprint: no cards even after many ticks")
        XCTAssertEqual(speech.speakCalls.count, 0)
        XCTAssertNil(app.inferenceWarning,
                     "ScenarioC is silent: not an error, so no warning (fix candidate)")
        XCTAssertNotNil(app.lastLatencyMs,
                        "lastLatencyMs IS set — that's the one live signal Cactus was reached")
    }

    // MARK: - Scenario D: Gemma emits prose instead of JSON
    //
    // Gemma-1B frequently ignores "return JSON only" and answers in prose.
    // WhisperEngine.parseWhisper cannot extract JSON; the tick is dropped.

    func testScenarioD_proseReplyIsDropped() async {
        let cactus = FakeCactus()
        cactus.outcomes = [.reply(
            "Here's an interesting stat: Messi has scored 7 goals this tournament."
        )]
        let (app, engine, speech) = makeEnv(cactus: cactus)
        seedPlay(app)

        await engine.triggerOnce()

        XCTAssertEqual(cactus.calls.count, 1)
        XCTAssertEqual(app.currentSession.statCards.count, 0,
                       "ScenarioD fingerprint: prose never becomes a card")
        XCTAssertEqual(speech.speakCalls.count, 0)
        XCTAssertNil(app.inferenceWarning)
        // NOTE: LivePaneView's manual whisper path (via the /btw button) has a
        // proseFallbackAnswer salvager. WhisperEngine's autonomous tick does
        // not — it relies strictly on JSON. That asymmetry surprised the
        // teammate.
    }

    // MARK: - Scenario E: healthy whisper round-trip
    //
    // Baseline — if this regresses, something is wrong with the pipeline
    // itself, not the integration.

    func testScenarioE_healthyPathAppendsCardAndSpeaks() async {
        let cactus = FakeCactus()
        cactus.outcomes = [.reply(
            #"{"player":"Messi","answer":"Messi with 3 shots on target.","source":"ESPN"}"#
        )]
        let (app, engine, speech) = makeEnv(cactus: cactus)
        seedPlay(app)

        await engine.triggerOnce()

        XCTAssertEqual(cactus.calls.count, 1)
        XCTAssertEqual(app.currentSession.statCards.count, 1)
        XCTAssertEqual(app.currentSession.statCards.last?.answer, "Messi with 3 shots on target.")
        XCTAssertEqual(speech.speakCalls, ["Messi with 3 shots on target."])
        XCTAssertNotNil(app.lastLatencyMs)
    }

    // MARK: - Observability gap: lastLatencyMs is the only tick signal
    //
    // If a teammate is asking "is the agent even running?", lastLatencyMs is
    // the only @Observable field WhisperEngine touches that reflects a
    // completed tick. This test pins that contract so nobody removes it.

    func testLastLatencyMsIsWrittenEvenWhenGemmaRefuses() async {
        let cactus = FakeCactus()
        cactus.outcomes = [.reply(#"{"no_verified_data":true}"#)]
        let (app, engine, _) = makeEnv(cactus: cactus)
        seedPlay(app)

        XCTAssertNil(app.lastLatencyMs, "fresh store — nothing has measured latency yet")
        await engine.triggerOnce()
        XCTAssertNotNil(app.lastLatencyMs,
                        "lastLatencyMs is the proof the engine actually reached Gemma")
    }

    // MARK: - Observability gap: a "skipped tick" leaves no trace on AppStore
    //
    // Pins current behavior. If we later add visible skip-reason state to
    // AppStore (so the UI can show "agent armed, waiting on feed"), this test
    // will fail and force us to update it — the desired direction.

    func testSkippedTickLeavesNoObservableTrace_regressionGuard() async {
        let cactus = FakeCactus()
        let (app, engine, _) = makeEnv(cactus: cactus)
        // No plays seeded → tick skips without ever calling cactus.

        let latencyBefore = app.lastLatencyMs
        let warningBefore = app.inferenceWarning

        await engine.triggerOnce()

        XCTAssertEqual(app.lastLatencyMs, latencyBefore,
                       "skipped tick must not touch latency")
        XCTAssertEqual(app.inferenceWarning, warningBefore,
                       "skipped tick must not touch warning")
        // When you add a skip-reason field to AppStore, update this test to
        // assert on it.
    }
}

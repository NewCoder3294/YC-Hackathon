import XCTest
import PlayByPlayKit
@testable import BroadcastBrain

/// Pure-logic tests for the helpers WhisperEngine uses to turn Gemma's raw
/// output into a StatCard. No Cactus, no AppStore, no async.
///
/// `@MainActor` because the helpers sit on a @MainActor class.
@MainActor
final class WhisperEngineParsingTests: XCTestCase {

    // MARK: - extractFirstJSON

    func testExtractFirstJSONSimple() {
        let raw = #"{"a":1}"#
        XCTAssertEqual(WhisperEngine.extractFirstJSON(raw), #"{"a":1}"#)
    }

    func testExtractFirstJSONWithSurroundingProse() {
        let raw = "sure, here you go:\n{\"answer\":\"yes\"}\nhope that helps"
        XCTAssertEqual(WhisperEngine.extractFirstJSON(raw), #"{"answer":"yes"}"#)
    }

    func testExtractFirstJSONNestedBraces() {
        let raw = #"{"a":{"b":{"c":1}},"d":2}"#
        XCTAssertEqual(WhisperEngine.extractFirstJSON(raw), raw)
    }

    func testExtractFirstJSONArraysInBody() {
        let raw = #"{"xs":[1,2,3],"y":"z"}"#
        XCTAssertEqual(WhisperEngine.extractFirstJSON(raw), raw)
    }

    func testExtractFirstJSONOnlyPicksFirstObject() {
        let raw = "{\"first\":true} then {\"second\":true}"
        XCTAssertEqual(WhisperEngine.extractFirstJSON(raw), #"{"first":true}"#)
    }

    func testExtractFirstJSONEmptyObject() {
        XCTAssertEqual(WhisperEngine.extractFirstJSON("{}"), "{}")
    }

    func testExtractFirstJSONNoBracesReturnsNil() {
        XCTAssertNil(WhisperEngine.extractFirstJSON("just prose, no json"))
    }

    func testExtractFirstJSONUnterminatedReturnsNil() {
        XCTAssertNil(WhisperEngine.extractFirstJSON("{\"a\":1"))
    }

    // MARK: - parseWhisper

    func testParseWhisperValidCardPreservesPlayerAndAnswer() {
        let raw = #"{"type":"whisper","player":"Messi","answer":"Messi has 3 shots on target.","source":"ESPN"}"#
        let result = WhisperEngine.parseWhisper(raw, latencyMs: 150)
        guard case .card(let card) = result else { return XCTFail("expected .card, got \(result)") }
        XCTAssertEqual(card.kind, .whisper)
        XCTAssertEqual(card.player, "Messi")
        XCTAssertEqual(card.answer, "Messi has 3 shots on target.")
        XCTAssertEqual(card.latencyMs, 150)
        XCTAssertEqual(card.rawTranscript, "", "auto-whisper cards keep rawTranscript empty")
    }

    func testParseWhisperMissingPlayerFallsBackToAgent() {
        let raw = #"{"answer":"Argentina 2-0 France at the 45th minute."}"#
        let result = WhisperEngine.parseWhisper(raw, latencyMs: 42)
        guard case .card(let card) = result else { return XCTFail("expected .card") }
        XCTAssertEqual(card.player, "Agent")
        XCTAssertEqual(card.answer, "Argentina 2-0 France at the 45th minute.")
    }

    func testParseWhisperWhitespacePlayerFallsBackToAgent() {
        let raw = #"{"player":"   ","answer":"something"}"#
        let result = WhisperEngine.parseWhisper(raw, latencyMs: 0)
        guard case .card(let card) = result else { return XCTFail("expected .card") }
        XCTAssertEqual(card.player, "Agent")
    }

    func testParseWhisperTrimsAnswerWhitespace() {
        let raw = "{\"answer\":\"  padded  \\n\"}"
        let result = WhisperEngine.parseWhisper(raw, latencyMs: 0)
        guard case .card(let card) = result else { return XCTFail("expected .card") }
        XCTAssertEqual(card.answer, "padded")
    }

    func testParseWhisperEmbeddedInProse() {
        let raw = "Sure — here is your whisper: {\"player\":\"Mbappé\",\"answer\":\"Mbappé has 2 goals.\"} done."
        let result = WhisperEngine.parseWhisper(raw, latencyMs: 0)
        guard case .card(let card) = result else { return XCTFail("expected .card") }
        XCTAssertEqual(card.player, "Mbappé")
    }

    func testParseWhisperNoVerifiedData() {
        let raw = #"{"no_verified_data":true}"#
        let result = WhisperEngine.parseWhisper(raw, latencyMs: 0)
        if case .noVerifiedData = result { return }
        XCTFail("expected .noVerifiedData, got \(result)")
    }

    func testParseWhisperNoVerifiedDataFalseIsNotNoVerifiedData() {
        let raw = #"{"no_verified_data":false,"answer":"fact"}"#
        let result = WhisperEngine.parseWhisper(raw, latencyMs: 0)
        guard case .card = result else { return XCTFail("expected .card when no_verified_data is false") }
    }

    func testParseWhisperMissingAnswerIsEmptyAnswer() {
        let raw = #"{"player":"Messi"}"#
        let result = WhisperEngine.parseWhisper(raw, latencyMs: 0)
        if case .emptyAnswer = result { return }
        XCTFail("expected .emptyAnswer, got \(result)")
    }

    func testParseWhisperEmptyAnswerString() {
        let raw = #"{"answer":"   "}"#
        let result = WhisperEngine.parseWhisper(raw, latencyMs: 0)
        if case .emptyAnswer = result { return }
        XCTFail("expected .emptyAnswer, got \(result)")
    }

    func testParseWhisperMalformedIsUnparseable() {
        let raw = "totally not json"
        let result = WhisperEngine.parseWhisper(raw, latencyMs: 0)
        if case .unparseable = result { return }
        XCTFail("expected .unparseable, got \(result)")
    }

    func testParseWhisperEmptyStringIsUnparseable() {
        let result = WhisperEngine.parseWhisper("", latencyMs: 0)
        if case .unparseable = result { return }
        XCTFail("expected .unparseable, got \(result)")
    }

    // MARK: - tailLines

    func testTailLinesEmpty() {
        XCTAssertEqual(WhisperEngine.tailLines(of: "", limit: 10), "")
    }

    func testTailLinesSingleLine() {
        XCTAssertEqual(WhisperEngine.tailLines(of: "only one line", limit: 10), "only one line")
    }

    func testTailLinesFewerThanLimit() {
        XCTAssertEqual(WhisperEngine.tailLines(of: "a\nb\nc", limit: 10), "a b c")
    }

    func testTailLinesExactlyLimit() {
        XCTAssertEqual(WhisperEngine.tailLines(of: "a\nb\nc", limit: 3), "a b c")
    }

    func testTailLinesMoreThanLimit() {
        XCTAssertEqual(WhisperEngine.tailLines(of: "a\nb\nc\nd\ne", limit: 3), "c d e")
    }

    func testTailLinesDropsEmptyLines() {
        // split(omittingEmptySubsequences: true) should strip blank lines.
        XCTAssertEqual(WhisperEngine.tailLines(of: "a\n\n\nb", limit: 10), "a b")
    }

    // MARK: - renderPlays

    func testRenderPlaysEmpty() {
        XCTAssertEqual(WhisperEngine.renderPlays([], compact: nil), "")
    }

    func testRenderPlaysUsesAthleteNameWhenMapped() throws {
        let compact = try Fixture.compact(athletes: [Fixture.Athlete(id: "a1", name: "Messi")])
        let plays = [try Fixture.play(
            id: "p1",
            text: "scores",
            clock: "45'",
            periodNumber: 1,
            athleteId: "a1"
        )]
        let out = WhisperEngine.renderPlays(plays, compact: compact)
        XCTAssertEqual(out, "- [45' P1] Messi: scores")
    }

    func testRenderPlaysFallsBackToTeamAbbreviation() throws {
        let compact = try Fixture.compact(teams: [Fixture.Team(id: "t1", name: "Argentina", abbr: "ARG")])
        let plays = [try Fixture.play(
            id: "p1",
            text: "kickoff",
            clock: "0'",
            periodNumber: 1,
            teamId: "t1"
        )]
        let out = WhisperEngine.renderPlays(plays, compact: compact)
        XCTAssertEqual(out, "- [0' P1] ARG: kickoff")
    }

    func testRenderPlaysFallsBackToTeamNameWhenAbbreviationMissing() throws {
        let compact = try Fixture.compact(teams: [Fixture.Team(id: "t1", name: "Argentina", abbr: nil)])
        let plays = [try Fixture.play(id: "p1", text: "event", teamId: "t1")]
        let out = WhisperEngine.renderPlays(plays, compact: compact)
        XCTAssertEqual(out, "- Argentina: event")
    }

    func testRenderPlaysWithoutClockOrPeriodDropsHeader() throws {
        let plays = [try Fixture.play(id: "p1", text: "generic event")]
        let out = WhisperEngine.renderPlays(plays, compact: nil)
        XCTAssertEqual(out, "- generic event")
    }

    func testRenderPlaysNoAthleteNoTeamOmitsWho() throws {
        let plays = [try Fixture.play(id: "p1", text: "whistle", clock: "12'", periodNumber: 2)]
        let out = WhisperEngine.renderPlays(plays, compact: nil)
        XCTAssertEqual(out, "- [12' P2] whistle")
    }

    func testRenderPlaysPreservesOrderAndJoinsWithNewline() throws {
        let compact = try Fixture.compact(athletes: [Fixture.Athlete(id: "a1", name: "Messi")])
        let plays = [
            try Fixture.play(id: "p1", text: "shot", clock: "30'", periodNumber: 1, athleteId: "a1"),
            try Fixture.play(id: "p2", text: "goal", clock: "31'", periodNumber: 1, athleteId: "a1")
        ]
        let out = WhisperEngine.renderPlays(plays, compact: compact)
        XCTAssertEqual(out, "- [30' P1] Messi: shot\n- [31' P1] Messi: goal")
    }

    func testRenderPlaysClockOnlyHeader() throws {
        let plays = [try Fixture.play(id: "p1", text: "kickoff", clock: "0'")]
        let out = WhisperEngine.renderPlays(plays, compact: nil)
        XCTAssertEqual(out, "- [0'] kickoff")
    }

    func testRenderPlaysPeriodOnlyHeader() throws {
        let plays = [try Fixture.play(id: "p1", text: "half", periodNumber: 2)]
        let out = WhisperEngine.renderPlays(plays, compact: nil)
        XCTAssertEqual(out, "- [P2] half")
    }
}

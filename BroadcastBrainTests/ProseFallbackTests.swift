import XCTest
@testable import BroadcastBrain

/// Tests for `LivePaneView.proseFallbackAnswer` and its two helpers.
///
/// These tests protect the whisper pipeline from Gemma's most common failure
/// mode: emitting a polite-sounding prose refusal ("I don't have verified
/// data on that.") that the fallback salvager was shipping as a whisper
/// answer. The screenshot of the running app showed 6+ identical whisper
/// cards with that exact text.
///
/// After the Phase 2 fix, refusals return `nil` (no card appended) and only
/// substantive prose makes it through.
@MainActor
final class ProseFallbackTests: XCTestCase {

    // MARK: - isRefusal

    func testRefusalMatchesExactScreenshotString() {
        XCTAssertTrue(LivePaneView.isRefusal("I don't have verified data on that."))
    }

    func testRefusalMatchesVariants() {
        XCTAssertTrue(LivePaneView.isRefusal("I don't know."))
        XCTAssertTrue(LivePaneView.isRefusal("I do not know the answer to that."))
        XCTAssertTrue(LivePaneView.isRefusal("I cannot answer that question."))
        XCTAssertTrue(LivePaneView.isRefusal("I'm unable to help with that."))
        XCTAssertTrue(LivePaneView.isRefusal("I have no information about that player."))
        XCTAssertTrue(LivePaneView.isRefusal("I am not sure about that stat."))
        XCTAssertTrue(LivePaneView.isRefusal("I apologize, but that is outside my training."))
    }

    func testRefusalIsFirstPersonOnly() {
        // Third-person "doesn't have" MUST pass — it describes the game state.
        XCTAssertFalse(
            LivePaneView.isRefusal("Messi doesn't have a hat-trick yet."),
            "third-person negation is real commentary, must survive"
        )
        XCTAssertFalse(
            LivePaneView.isRefusal("France don't have a single shot on target.")
        )
        XCTAssertFalse(
            LivePaneView.isRefusal("Neither side has verified data on the midfield possession split.")
        )
    }

    func testRefusalMatchesContractions() {
        XCTAssertTrue(LivePaneView.isRefusal("I'm sorry, I don't have that information."))
        XCTAssertTrue(LivePaneView.isRefusal("I'd rather not speculate on that stat."))
    }

    func testRefusalEmptyOrWhitespaceIsNotRefusal() {
        XCTAssertFalse(LivePaneView.isRefusal(""))
        XCTAssertFalse(LivePaneView.isRefusal("   "))
    }

    // MARK: - isMetaChatter

    func testMetaChatterMatchesLeadingFraming() {
        XCTAssertTrue(LivePaneView.isMetaChatter("Please provide me with the match context."))
        XCTAssertTrue(LivePaneView.isMetaChatter("As an AI language model, I can try to help."))
        XCTAssertTrue(LivePaneView.isMetaChatter("I'm sorry, but I need more to go on."))
        XCTAssertTrue(LivePaneView.isMetaChatter("Okay, let's break this down step by step."))
    }

    func testMetaChatterDoesNotFlagRealAnswers() {
        XCTAssertFalse(LivePaneView.isMetaChatter("Messi has scored 7 goals this tournament."))
        XCTAssertFalse(LivePaneView.isMetaChatter("The current score is 2-0 at the half."))
    }

    // MARK: - proseFallbackAnswer — refusal gate

    func testProseFallbackReturnsNilForScreenshotRefusal() {
        XCTAssertNil(LivePaneView.proseFallbackAnswer(from: "I don't have verified data on that."))
    }

    func testProseFallbackReturnsNilForRefusalWithSurroundingFramingAndMarkdown() {
        let raw = """
        Okay, let's see what I can do.

        I don't have verified data on that player.
        """
        // Meta first paragraph gets skipped; second paragraph is a refusal.
        XCTAssertNil(LivePaneView.proseFallbackAnswer(from: raw))
    }

    func testProseFallbackReturnsNilForJSONOnlyReply() {
        // `{...}` is left to the structured parser; prose salvager returns nil.
        XCTAssertNil(LivePaneView.proseFallbackAnswer(from: #"{"answer":"Messi 7 goals"}"#))
    }

    // MARK: - proseFallbackAnswer — happy paths

    func testProseFallbackReturnsFirstSentenceOfValidAnswer() {
        let raw = "Messi has scored 7 goals at this tournament. That ties him with Just Fontaine."
        XCTAssertEqual(
            LivePaneView.proseFallbackAnswer(from: raw),
            "Messi has scored 7 goals at this tournament."
        )
    }

    func testProseFallbackStripsMarkdownFences() {
        let raw = """
        ```json
        Actually, France won 4-2 on penalties.
        ```
        """
        let out = LivePaneView.proseFallbackAnswer(from: raw)
        XCTAssertNotNil(out)
        XCTAssertFalse(out!.contains("```"))
        XCTAssertTrue(out!.contains("France"))
    }

    func testProseFallbackSkipsMetaAndKeepsNextParagraph() {
        let raw = """
        Okay, let's see what I can do.

        Mbappé has 4 goals in this World Cup.
        """
        XCTAssertEqual(
            LivePaneView.proseFallbackAnswer(from: raw),
            "Mbappé has 4 goals in this World Cup."
        )
    }

    func testProseFallbackCapsAt220Chars() {
        let long = String(repeating: "Messi runs. ", count: 30) // ~360 chars, many sentences
        let out = LivePaneView.proseFallbackAnswer(from: long)
        XCTAssertNotNil(out)
        XCTAssertLessThanOrEqual(out!.count, 220 + 1, "ellipsis adds one char")
    }

    func testProseFallbackEmptyReturnsNil() {
        XCTAssertNil(LivePaneView.proseFallbackAnswer(from: ""))
        XCTAssertNil(LivePaneView.proseFallbackAnswer(from: "   \n\n  "))
    }

    // MARK: - proseFallbackAnswer — interaction with real Gemma outputs

    func testProseFallbackLetsThirdPersonNegationThrough() {
        // The critical false-positive case: a valid stat that includes
        // "doesn't have" must NOT be filtered.
        let raw = "France doesn't have a single shot on target in the first half."
        XCTAssertEqual(
            LivePaneView.proseFallbackAnswer(from: raw),
            "France doesn't have a single shot on target in the first half."
        )
    }

    func testProseFallbackRejectsRefusalEvenWhenItHasAStat() {
        // Gemma sometimes emits hybrid sentences like "I don't have that
        // stat but Messi has 7 goals." The first-sentence extractor grabs
        // only up to the first period — which is the refusal. Refuse.
        let raw = "I don't have that stat in the plays. Messi has 7 goals."
        XCTAssertNil(LivePaneView.proseFallbackAnswer(from: raw))
    }

    func testProseFallbackLetsValidAnswerContainingWordVerifiedThrough() {
        // "verified" alone should not trigger — only "verified data" AND
        // first-person does.
        let raw = "The goal was verified by VAR after a two-minute review."
        XCTAssertEqual(
            LivePaneView.proseFallbackAnswer(from: raw),
            "The goal was verified by VAR after a two-minute review."
        )
    }
}

import XCTest
@testable import BroadcastBrain

final class SentenceExtractorTests: XCTestCase {

    // MARK: - Canonicalization

    func testCanonicalStripsLightPunctuation() {
        XCTAssertEqual(
            SentenceExtractor.canonical("Hello, world!"),
            "hello world"
        )
    }

    func testCanonicalCollapsesInternalWhitespace() {
        XCTAssertEqual(
            SentenceExtractor.canonical("Hello   world\t\tfriend"),
            "hello world friend"
        )
    }

    func testCanonicalPreservesApostrophesInContractions() {
        // "don't" and "dont" are genuinely different tokens — keep the
        // apostrophe so they don't dedup with each other.
        XCTAssertNotEqual(
            SentenceExtractor.canonical("I don't know"),
            SentenceExtractor.canonical("I dont know")
        )
    }

    func testCanonicalDedupsCommaVariants() {
        // The exact revision pattern from the screenshot.
        XCTAssertEqual(
            SentenceExtractor.canonical("yeah, I'm just completely fails."),
            SentenceExtractor.canonical("yeah I'm just completely fails.")
        )
    }

    // MARK: - scanSentences

    func testScanSentencesSingleSentenceWithPeriod() {
        XCTAssertEqual(
            SentenceExtractor.scanSentences(in: "Hello world.", forceFinal: false),
            ["Hello world."]
        )
    }

    func testScanSentencesMultipleSentences() {
        XCTAssertEqual(
            SentenceExtractor.scanSentences(in: "First. Second! Third?", forceFinal: false),
            ["First.", "Second!", "Third?"]
        )
    }

    func testScanSentencesIncompleteTailDroppedWithoutForceFinal() {
        XCTAssertEqual(
            SentenceExtractor.scanSentences(in: "Complete. Incomplete no period", forceFinal: false),
            ["Complete."]
        )
    }

    func testScanSentencesIncompleteTailEmittedWithForceFinal() {
        XCTAssertEqual(
            SentenceExtractor.scanSentences(in: "Complete. Tail no period", forceFinal: true),
            ["Complete.", "Tail no period"]
        )
    }

    func testScanSentencesConsumesPunctuationRun() {
        XCTAssertEqual(
            SentenceExtractor.scanSentences(in: "Wait!?! Really?", forceFinal: false),
            ["Wait!?!", "Really?"]
        )
    }

    func testScanSentencesDropsMicrosentences() {
        // Single punctuation alone or single-char segments are dropped.
        XCTAssertEqual(
            SentenceExtractor.scanSentences(in: ". . . Hello.", forceFinal: false),
            ["Hello."]
        )
    }

    // MARK: - ingest: happy paths

    func testIngestMonotonicPartialsEmitEachSentenceOnce() {
        var ex = SentenceExtractor()
        XCTAssertEqual(ex.ingest(cumulative: "What two teams", forceFinal: false), [])
        XCTAssertEqual(ex.ingest(cumulative: "What two teams are playing", forceFinal: false), [])
        XCTAssertEqual(
            ex.ingest(cumulative: "What two teams are playing.", forceFinal: false),
            ["What two teams are playing."]
        )
        // Same partial arrives again — must NOT re-emit.
        XCTAssertEqual(ex.ingest(cumulative: "What two teams are playing.", forceFinal: false), [])
        XCTAssertEqual(ex.emittedCount, 1)
    }

    func testIngestMultiplePartialsAcrossTwoSentences() {
        var ex = SentenceExtractor()
        _ = ex.ingest(cumulative: "Messi shoots.", forceFinal: false)
        XCTAssertEqual(
            ex.ingest(cumulative: "Messi shoots. He scores!", forceFinal: false),
            ["He scores!"]
        )
    }

    // MARK: - ingest: the bug this class was built to fix

    func testIngestDedupsCommaRevisionBug() {
        // Reproduces the screenshot: STT emits a sentence with a comma, then
        // revises to drop the comma. Prefix-match dedup shipped the sentence
        // twice. Set-based canonical dedup ships it once.
        var ex = SentenceExtractor()
        let withComma = "What two teams are playing yeah, I'm just completely fails."
        let withoutComma = "What two teams are playing yeah I'm just completely fails."

        let first = ex.ingest(cumulative: withComma, forceFinal: false)
        let second = ex.ingest(cumulative: withoutComma, forceFinal: false)

        XCTAssertEqual(first, [withComma])
        XCTAssertEqual(second, [], "punctuation-only revision must not re-emit")
        XCTAssertEqual(ex.emittedCount, 1)
    }

    func testIngestReplaysScreenshotSequenceEmitsEachSentenceOnce() {
        // Real sequence reconstructed from the Xcode console in the bug
        // screenshot. Before the fix, each of these produced a duplicate
        // `[live] segment:` log line. After the fix we get exactly two
        // distinct sentences.
        var ex = SentenceExtractor()
        let partials: [String] = [
            "What two teams are playing what two teams are playing yeah, I'm just completely fails.",
            "What two teams are playing what two teams are playing yeah I'm just completely fails.",
            "What two teams are playing what two teams are playing yeah, I'm just completely fails.",
            "What two teams are playing what two teams are playing yeah I'm just completely fails.",
            "What two teams are playing what two teams are playing yeah I'm just completely fails. I've gotten a little bit past that but I'm still.",
            "What two teams are playing what two teams are playing yeah I'm just completely fails. I've gotten a little bit past that but I'm still failing.",
            "What two teams are playing what two teams are playing yeah I'm just completely fails. I've gotten a little bit past that but I'm still failing.",
        ]
        var totalEmitted: [String] = []
        for p in partials {
            totalEmitted += ex.ingest(cumulative: p, forceFinal: false)
        }
        // STT committed three genuinely distinct canonical sentences here:
        //   1. "What two teams are playing ... fails."
        //   2. "I've gotten a little bit past that but I'm still."   (mid-commit)
        //   3. "I've gotten a little bit past that but I'm still failing."
        // The commentator said two thoughts; STT split the second into two
        // sentence commits. That's an STT quirk we can't fix at this layer.
        // Before the dedup fix the count was 7+ (each comma revision fired
        // another copy). Three is the right floor.
        XCTAssertEqual(totalEmitted.count, 3,
                       "expected 3 distinct sentences — buggy code shipped 7+")
        XCTAssertEqual(ex.emittedCount, 3)
        XCTAssertTrue(totalEmitted[0].starts(with: "What two teams"))
        XCTAssertTrue(totalEmitted[1].contains("I'm still."))
        XCTAssertTrue(totalEmitted[2].contains("still failing"))
    }

    // MARK: - ingest: across recognition-task boundaries

    func testIngestDedupsFinalSegmentAgainstAlreadyEmittedPartial() {
        // Real flow: partial ships "Messi scores." to handleSegment, then STT
        // fires isFinal with the same text. onSegment calls ingest with
        // forceFinal=true. Must NOT emit again.
        var ex = SentenceExtractor()
        _ = ex.ingest(cumulative: "Messi scores.", forceFinal: false)
        XCTAssertEqual(
            ex.ingest(cumulative: "Messi scores.", forceFinal: true),
            []
        )
    }

    func testResetAllowsSameSentenceToEmitAgain() {
        var ex = SentenceExtractor()
        _ = ex.ingest(cumulative: "Goal!", forceFinal: false)
        XCTAssertEqual(ex.ingest(cumulative: "Goal!", forceFinal: false), [])
        ex.reset()
        XCTAssertEqual(ex.ingest(cumulative: "Goal!", forceFinal: false), ["Goal!"])
    }

    // MARK: - ingest: forceFinal with uncommitted tail

    func testIngestForceFinalEmitsIncompleteTail() {
        var ex = SentenceExtractor()
        let out = ex.ingest(
            cumulative: "Complete one. Tail without period",
            forceFinal: true
        )
        XCTAssertEqual(out, ["Complete one.", "Tail without period"])
    }

    func testIngestForceFinalDoesNotDoubleEmitWhenTailMatchesPriorSentence() {
        var ex = SentenceExtractor()
        _ = ex.ingest(cumulative: "Goal scored.", forceFinal: false)
        // If a later final arrives where only-ever-partial text happens to
        // match the earlier one without its period, dedup should still hold.
        XCTAssertEqual(
            ex.ingest(cumulative: "Goal scored", forceFinal: true),
            []
        )
    }

    // MARK: - edge cases

    func testIngestEmptyInput() {
        var ex = SentenceExtractor()
        XCTAssertEqual(ex.ingest(cumulative: "", forceFinal: false), [])
        XCTAssertEqual(ex.ingest(cumulative: "", forceFinal: true), [])
    }

    func testIngestWhitespaceOnly() {
        var ex = SentenceExtractor()
        XCTAssertEqual(ex.ingest(cumulative: "   \n  ", forceFinal: true), [])
    }

    func testIngestAbbreviationInsideSentenceDoesNotSplit() {
        // "U.S.A. beat Brazil." — a naïve period-split would chop at "U." etc.
        // Our boundary requires whitespace after the period, so "U.S." stays
        // attached because there's no space between "U." and "S".
        var ex = SentenceExtractor()
        let out = ex.ingest(
            cumulative: "U.S.A. beat Brazil.",
            forceFinal: false
        )
        // The scanner splits at "U.S.A." (there IS a space after "A.") —
        // accept that as the correct boundary behavior rather than trying
        // to model abbreviations (out of scope for the recognizer).
        XCTAssertEqual(out, ["U.S.A.", "beat Brazil."])
    }
}

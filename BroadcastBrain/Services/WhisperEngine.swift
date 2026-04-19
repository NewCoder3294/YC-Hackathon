import Foundation
import Observation
import PlayByPlayKit
import os

private let log = Logger(subsystem: "com.broadcastbrain.mac", category: "whisper")

/// Periodic inference driver. While `isRunning`, every `intervalSeconds` the
/// engine:
///   1. pulls the last 50 plays from PlayByPlayStore,
///   2. pulls the last ~10 lines of the rolling mic transcript,
///   3. asks Cactus for one stat useful for the NEXT 30s of broadcast,
///   4. renders the response as a `.whisper` StatCard (with empty rawTranscript
///      to mark it as an auto-whisper) and reads the answer aloud via TTS.
@MainActor
@Observable
final class WhisperEngine {
    var isRunning: Bool = false
    var intervalSeconds: TimeInterval = 30

    private weak var store: AppStore?
    private let cactus: CactusService
    private let tts: any SpeechSynthesizing

    private var loopTask: Task<Void, Never>?

    init(cactus: CactusService, tts: any SpeechSynthesizing) {
        self.cactus = cactus
        self.tts = tts
    }

    /// Attach the store after construction. Breaks the init cycle where
    /// AppStore owns WhisperEngine but WhisperEngine needs AppStore to read
    /// transcript + plays.
    func attach(store: AppStore) {
        self.store = store
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        log.info("start (interval=\(self.intervalSeconds)s)")

        loopTask = Task { [weak self] in
            // Run one tick quickly so the first whisper lands inside ~5–8s.
            try? await Task.sleep(nanoseconds: 5 * NSEC_PER_SEC)
            while let self, self.isRunning, !Task.isCancelled {
                await self.tickOnce()
                let interval = self.intervalSeconds
                try? await Task.sleep(nanoseconds: UInt64(interval * Double(NSEC_PER_SEC)))
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        loopTask?.cancel()
        loopTask = nil
        tts.stop()
        log.info("stop")
    }

    /// On-demand single fire (used by the "Whisper now" UI affordance).
    func triggerOnce() async {
        await tickOnce()
    }

    // MARK: - Tick

    private func tickOnce() async {
        guard let store else { return }

        let plays = store.playByPlayStore.plays
        let compact = store.playByPlayStore.currentCompact
        let transcriptTail = Self.tailLines(of: store.currentSession.transcript, limit: 10)

        // Whispers are strictly grounded in the play-by-play feed. Running
        // Gemma without plays makes the system prompt's "use only facts from
        // the plays payload" rule force every response to no_verified_data,
        // which spams the log and wastes an inference slot. Require plays.
        guard !plays.isEmpty else {
            log.debug("tick skip — no plays (no live feed attached)")
            store.lastWhisperSkip = .noPlays
            return
        }

        let playsBlock = Self.renderPlays(plays, compact: compact)
        let leagueKey = store.currentSession.match?.leagueKey ?? "n/a"

        let system = Self.systemPrompt
        let user = """
        Match: \(store.currentSession.title)
        League: \(leagueKey)

        Last \(plays.count) plays (most recent last):
        \(playsBlock.isEmpty ? "(no live plays available)" : playsBlock)

        Commentator said recently:
        "\(transcriptTail.isEmpty ? "(no transcript yet)" : transcriptTail)"
        """

        let started = Date()
        do {
            let reply = try await cactus.complete(system: system, user: user)
            let latency = Int(Date().timeIntervalSince(started) * 1000)
            store.lastLatencyMs = latency

            let parsed = Self.parseWhisper(reply, latencyMs: latency)
            switch parsed {
            case .card(let card):
                store.appendStatCard(card)
                store.lastWhisperSkip = nil
                if let answer = card.answer, !answer.isEmpty {
                    tts.speak(answer)
                }
                return
            case .noVerifiedData:
                log.debug("tick skip — Gemma returned no_verified_data")
                store.lastWhisperSkip = .noVerifiedData
                return
            case .emptyAnswer:
                log.debug("tick skip — Gemma JSON had empty answer; raw=\(reply.prefix(200), privacy: .public)")
                store.lastWhisperSkip = .emptyAnswer
                return
            case .unparseable:
                log.debug("tick skip — could not extract JSON; raw=\(reply.prefix(200), privacy: .public)")
                store.lastWhisperSkip = .unparseable
                return
            }
        } catch {
            log.error("tick inference failed: \(error.localizedDescription, privacy: .public)")
            store.inferenceWarning = "Whisper engine: \(error.localizedDescription)"
            store.lastWhisperSkip = .cactusError(message: error.localizedDescription)
        }
    }

    // MARK: - Prompt

    private static let systemPrompt = """
    You are a live broadcast stats whisperer. You produce ONE short, useful stat
    the commentator can drop in the NEXT 30 seconds of play. You receive:
    - The last ~50 plays from the official play-by-play feed (the ground truth).
    - The last few sentences the commentator just said (context — audio is ~5s
      delayed from what the feed shows).

    Return STRICTLY ONE JSON object:
    {"type":"whisper","player":"<name or empty>","answer":"<one sentence, <=25 words, a specific number or contextual fact derivable from the plays>","source":"ESPN play-by-play"}

    If nothing interesting can be said from the plays, return {"no_verified_data":true}.
    Do NOT invent numbers. Only use facts present in the plays payload.
    """

    // MARK: - Rendering

    /// Turn a CompactPlay into "[clock P{period}] {player or team}: {text}".
    /// Internal so LivePaneView's handleSegment can reuse the exact format
    /// WhisperEngine's autonomous tick uses — Gemma's output stays consistent
    /// across both whisper entry points.
    static func renderPlays(_ plays: [CompactPlay], compact: CompactGame?) -> String {
        guard !plays.isEmpty else { return "" }
        let athletes = compact?.athletes ?? [:]
        let teams = compact?.teams ?? [:]

        return plays.map { p in
            let clock = p.clock ?? ""
            let period: String
            if let pn = p.period?.number { period = "P\(pn)" } else { period = "" }
            let who: String
            if let aid = p.participants?.first?.athleteId, let a = athletes[aid] {
                who = a.name
            } else if let tid = p.teamId, let t = teams[tid] {
                who = t.abbreviation ?? t.name ?? "team"
            } else {
                who = ""
            }
            let text = p.text ?? ""
            let header = [clock, period].filter { !$0.isEmpty }.joined(separator: " ")
            let body = who.isEmpty ? text : "\(who): \(text)"
            if header.isEmpty {
                return "- \(body)"
            } else {
                return "- [\(header)] \(body)"
            }
        }.joined(separator: "\n")
    }

    static func tailLines(of transcript: String, limit: Int) -> String {
        let lines = transcript.split(separator: "\n", omittingEmptySubsequences: true)
        guard !lines.isEmpty else { return "" }
        let tail = lines.suffix(limit)
        return tail.joined(separator: " ")
    }

    // MARK: - Parsing

    enum WhisperParseResult {
        case card(StatCard)
        case noVerifiedData
        case emptyAnswer
        case unparseable
    }

    static func parseWhisper(_ raw: String, latencyMs: Int) -> WhisperParseResult {
        // Cactus sometimes wraps JSON in chatter. Grab the first {...} block.
        guard let jsonString = extractFirstJSON(raw),
              let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return .unparseable }
        if obj["no_verified_data"] as? Bool == true { return .noVerifiedData }

        let answer = (obj["answer"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !answer.isEmpty else { return .emptyAnswer }

        let player = (obj["player"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return .card(StatCard(
            kind: .whisper,
            player: player.isEmpty ? "Agent" : player,
            rawTranscript: "", // empty rawTranscript marks this as an auto-whisper
            latencyMs: latencyMs,
            answer: answer
        ))
    }

    static func extractFirstJSON(_ s: String) -> String? {
        guard let firstBrace = s.firstIndex(of: "{") else { return nil }
        var depth = 0
        var end: String.Index?
        for i in s[firstBrace...].indices {
            let ch = s[i]
            if ch == "{" { depth += 1 }
            else if ch == "}" {
                depth -= 1
                if depth == 0 { end = i; break }
            }
        }
        guard let e = end else { return nil }
        return String(s[firstBrace...e])
    }
}

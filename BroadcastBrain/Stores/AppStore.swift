import Foundation
import Observation
import PlayByPlayKit

enum Surface: String, CaseIterable, Identifiable {
    case live, squads, research, archive, plays, playsDB
    var id: String { rawValue }
}

enum SpottingMode: String, CaseIterable, Identifiable {
    case stats, story, tactical
    var id: String { rawValue }

    var label: String {
        switch self {
        case .stats: return "STATS"
        case .story: return "STORY"
        case .tactical: return "TACTICAL"
        }
    }
}

enum LiveState: Equatable {
    case idle
    case listening
    case processing
    case error(String)
}

@MainActor
@Observable
final class AppStore {
    var selectedSurface: Surface = .live
    var selectedArchiveId: UUID?
    var currentSession: Session
    var liveState: LiveState = .idle
    var partialTranscript: String = ""
    var lastLatencyMs: Int?
    /// Last inference failure shown as a persistent banner on the Live pane.
    /// Set when Cactus isn't loaded or a completion fails. Nil when things
    /// are healthy.
    var inferenceWarning: String?
    /// When true the ContentView presents NewMatchSheet. Driven by the sidebar
    /// `+ New Session` button. Dismissed on Cancel or Create.
    var showNewMatchSheet: Bool = false

    let sessionStore: SessionStore
    let cactus: CactusService
    let matchCache: MatchCache?
    let playByPlayStore: PlayByPlayStore
    let speech: SpeechSynthesisService
    let whisperEngine: WhisperEngine

    init(
        sessionStore: SessionStore,
        cactus: CactusService,
        playByPlayStore: PlayByPlayStore,
        speech: SpeechSynthesisService,
        whisperEngine: WhisperEngine
    ) {
        self.sessionStore = sessionStore
        self.cactus = cactus
        self.playByPlayStore = playByPlayStore
        self.speech = speech
        self.whisperEngine = whisperEngine

        if let url = Bundle.main.url(forResource: "match_cache", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let cache = try? JSONDecoder().decode(MatchCache.self, from: data) {
            self.matchCache = cache
        } else {
            self.matchCache = nil
        }

        // Seed the default hackathon match so first launch has something live.
        let seededMatch = Match.sampleArgFra2022
        let title = seededMatch.title

        // Reuse an empty session for today's match if one already exists.
        let cal = Calendar.current
        if let reusable = sessionStore.sessions.first(where: { s in
            s.title == title
                && s.transcript.isEmpty
                && s.statCards.isEmpty
                && s.notes.isEmpty
                && s.researchMessages.isEmpty
                && cal.isDateInToday(s.createdAt)
        }) {
            self.currentSession = reusable
        } else {
            let fresh = Session(title: title, match: seededMatch)
            self.currentSession = fresh
            sessionStore.save(fresh)
        }

        // Sweep any stray empty duplicate sessions (from pre-fix launches)
        sessionStore.purgeEmptyDuplicates(except: self.currentSession.id)

        // Back-link whisper engine to self so it can read transcript + plays.
        whisperEngine.attach(store: self)

        // Surface cactus availability up front so the first mic tap isn't a
        // silent no-op when the model is missing.
        if cactus is UnavailableCactusService {
            self.inferenceWarning = "Gemma model not found. Install `gemma.gguf` (see README) and relaunch — the app starts but cannot produce stats until the model is present."
        }
    }

    /// The bundled match_cache is only valid for the match it was authored
    /// against (currently Argentina vs France 2022). Injecting its facts into
    /// an unrelated session's prompt causes Gemma to hallucinate Messi/Mbappé
    /// stats for whatever the commentator is actually talking about. Require
    /// both team names to appear in the cache title before using it.
    var matchCacheForCurrentSession: MatchCache? {
        guard let cache = matchCache, let match = currentSession.match else { return nil }
        let cacheTitle = cache.title.lowercased()
        let home = match.homeTeam.lowercased()
        let away = match.awayTeam.lowercased()
        guard !home.isEmpty, !away.isEmpty,
              cacheTitle.contains(home), cacheTitle.contains(away)
        else { return nil }
        return cache
    }

    func appendStatCard(_ card: StatCard) {
        currentSession.statCards.append(card)
        sessionStore.save(currentSession)
    }

    func appendTranscript(_ text: String) {
        if !currentSession.transcript.isEmpty { currentSession.transcript += "\n" }
        currentSession.transcript += text
        sessionStore.save(currentSession)
    }

    func appendResearchMessage(_ msg: ChatMessage) {
        currentSession.researchMessages.append(msg)
        sessionStore.save(currentSession)
    }

    func updateNotes(_ text: String) {
        currentSession.notes = text
        sessionStore.save(currentSession)
    }

    /// Triggered by the sidebar `+ New Session` button. Opens the match form.
    /// The actual session is created when the user submits via `createSession(from:)`.
    func newSession() {
        showNewMatchSheet = true
    }

    /// Called from NewMatchSheet when the user taps Create.
    func createSession(from match: Match) {
        let s = Session(title: match.title, match: match)
        sessionStore.save(s)
        currentSession = s
        selectedArchiveId = nil
        selectedSurface = .live
        showNewMatchSheet = false
        startPlayByPlayIfNeeded(for: match)
    }

    /// Kick off (or resume) the play-by-play stream for a match that carries
    /// an ESPN league + game id. Safe to call when no feed is linked — it's a
    /// no-op in that case.
    func startPlayByPlayIfNeeded(for match: Match) {
        guard let leagueKey = match.leagueKey,
              let gameId = match.gameId,
              let league = League.all.first(where: { $0.key == leagueKey })
        else { return }

        if playByPlayStore.selectedGame?.id == gameId,
           playByPlayStore.isStreaming {
            return
        }

        playByPlayStore.selectLeague(league)
        Task { @MainActor in
            await playByPlayStore.loadLiveGames()
            let match = playByPlayStore.games.first(where: { $0.id == gameId })
            if let match {
                playByPlayStore.startStreaming(match)
            }
        }
    }

    /// Used by endMatch — reuses the current match for a fresh session without
    /// asking the commentator to re-enter match details.
    func newSessionKeepingCurrentMatch() {
        let reusedMatch = currentSession.match ?? Match.sampleArgFra2022
        let s = Session(title: reusedMatch.title, match: reusedMatch)
        sessionStore.save(s)
        currentSession = s
        selectedArchiveId = nil
        selectedSurface = .live
    }
}

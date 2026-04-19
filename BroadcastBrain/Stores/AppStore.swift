import Foundation
import Observation

enum Surface: String, CaseIterable, Identifiable {
    case live, squads, research, news, archive, plays, playsDB
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

@Observable
final class AppStore {
    var selectedSurface: Surface = .live
    var selectedArchiveId: UUID?
    var currentSession: Session
    var liveState: LiveState = .idle
    var partialTranscript: String = ""
    var lastLatencyMs: Int?
    /// When true the ContentView presents NewMatchSheet. Driven by the sidebar
    /// `+ New Session` button. Dismissed on Cancel or Create.
    var showNewMatchSheet: Bool = false
    /// Shows TeamSetupView full-screen when true (first launch or user-triggered refresh).
    var showingSetup: Bool = false
    var spottingMode: SpottingMode? = nil

    let sessionStore: SessionStore
    let cactus: CactusService
    var matchCache: MatchCache?
    let playByPlayStore: PlayByPlayStore

    init(sessionStore: SessionStore, cactus: CactusService, playByPlayStore: PlayByPlayStore) {
        self.sessionStore = sessionStore
        self.cactus = cactus
        self.playByPlayStore = playByPlayStore

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

    /// Called by TeamSetupView after the fetch completes — swaps the in-memory
    /// match cache and starts a fresh session for the new matchup.
    func loadMatchCache(_ cache: MatchCache) {
        matchCache = cache
        showingSetup = false

        let fresh = Session(title: cache.title)
        sessionStore.save(fresh)
        currentSession = fresh
        selectedArchiveId = nil
        selectedSurface = .research
    }

    /// Called by the sidebar "refresh" button to reopen the setup flow.
    func presentSetup() {
        showingSetup = true
    }
}

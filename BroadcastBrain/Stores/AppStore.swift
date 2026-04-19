import Foundation
import Observation

enum Surface: String, CaseIterable, Identifiable {
    case live, squads, research, news, archive
    var id: String { rawValue }
}

enum SpottingMode: String, CaseIterable, Identifiable {
    case stats, story, tactical
    var id: String { rawValue }

    var label: String {
        switch self {
        case .stats:    return "STATS"
        case .story:    return "STORY"
        case .tactical: return "TACTICAL"
        }
    }
}

enum LiveState: Equatable {
    case idle, listening, processing
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
    var spottingMode: SpottingMode? = nil
    var showingSetup: Bool = false
    private(set) var matchCache: MatchCache?

    let sessionStore: SessionStore
    let cactus: CactusService

    // Saved cache location — overrides bundled resource after first user fetch
    private static let savedCacheURL: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("BroadcastBrain/match_cache.json")

    init(sessionStore: SessionStore, cactus: CactusService) {
        self.sessionStore = sessionStore
        self.cactus = cactus

        // Only user-saved cache counts — no bundled fallback, so first launch always
        // forces the team setup screen for a tailored experience.
        let initialCache = Self.loadSavedCache()
        self.matchCache = initialCache

        let title = initialCache?.title ?? "New Match"

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
            let fresh = Session(title: title)
            self.currentSession = fresh
            sessionStore.save(fresh)
        }

        sessionStore.purgeEmptyDuplicates(except: self.currentSession.id)

        // Show setup screen if there's no cache at all
        if self.matchCache == nil {
            self.showingSetup = true
        }
    }

    // Called by TeamSetupView after a successful fetch
    func loadMatchCache(_ cache: MatchCache) {
        matchCache = cache
        spottingMode = nil
        showingSetup = false
        Self.persistCache(cache)

        // Start a fresh session for the new match
        let fresh = Session(title: cache.title)
        sessionStore.save(fresh)
        currentSession = fresh
        selectedSurface = .research
    }

    func presentSetup() {
        showingSetup = true
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

    func newSession() {
        let title = matchCache?.title ?? "New Session"
        let s = Session(title: title)
        sessionStore.save(s)
        currentSession = s
        selectedArchiveId = nil
        selectedSurface = .live
    }

    // MARK: - Cache persistence

    private static func loadSavedCache() -> MatchCache? {
        guard FileManager.default.fileExists(atPath: savedCacheURL.path),
              let data = try? Data(contentsOf: savedCacheURL) else { return nil }
        return try? JSONDecoder().decode(MatchCache.self, from: data)
    }

    private static func persistCache(_ cache: MatchCache) {
        let dir = savedCacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? enc.encode(cache).write(to: savedCacheURL, options: .atomic)
    }
}

import Foundation
import Observation

enum Surface: String, CaseIterable, Identifiable {
    case live, research
    var id: String { rawValue }
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

    let sessionStore: SessionStore
    let cactus: CactusService
    let matchCache: MatchCache?

    init(sessionStore: SessionStore, cactus: CactusService) {
        self.sessionStore = sessionStore
        self.cactus = cactus

        if let url = Bundle.main.url(forResource: "match_cache", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let cache = try? JSONDecoder().decode(MatchCache.self, from: data) {
            self.matchCache = cache
        } else {
            self.matchCache = nil
        }

        let title = matchCache?.title ?? "Argentina vs France · 2022 WC Final"
        self.currentSession = Session(title: title)
        sessionStore.save(self.currentSession)
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
}

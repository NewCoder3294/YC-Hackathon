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

        // If the current session already carries a linked ESPN game, resume it.
        if let match = currentSession.match {
            startPlayByPlayIfNeeded(for: match)
        }
        // Otherwise probe ESPN for an actually-live game across the common
        // leagues so the whisper agent has real plays to ground on, even when
        // the user is on the seeded sample session.
        Task { @MainActor in
            await autoAttachLiveGameIfIdle()
        }
    }

    /// Preferred league order for auto-attach. Soccer first because it tends
    /// to have overlapping live windows across European leagues, then the
    /// big US leagues as fallbacks.
    private static let autoAttachLeagueKeys: [String] = [
        "epl", "laliga", "seriea", "bundesliga", "ligue1", "ucl", "mls",
        "nba", "nfl", "nhl", "mlb"
    ]

    /// Probe ESPN's scoreboards in order and start streaming the first game
    /// whose status indicates it's actually in progress. No-op if a stream
    /// is already active — we never override an explicitly chosen feed.
    func autoAttachLiveGameIfIdle() async {
        if playByPlayStore.isStreaming {
            print("[pbp] auto-attach skipped — stream already active")
            return
        }
        for key in Self.autoAttachLeagueKeys {
            guard let league = PlayByPlayKit.League.all.first(where: { $0.key == key }) else { continue }
            do {
                let games = try await PlayByPlay.getLiveGames(league)
                guard let live = Self.pickInProgress(from: games) else {
                    continue
                }
                playByPlayStore.selectLeague(league)
                playByPlayStore.games = games
                playByPlayStore.startStreaming(live)
                print("[pbp] auto-attached \(league.displayName) — \(live.shortName) [\(live.status)]")
                return
            } catch {
                print("[pbp] auto-attach probe failed for \(key): \(error.localizedDescription)")
            }
        }
        print("[pbp] auto-attach: no live games found across \(Self.autoAttachLeagueKeys.count) leagues")
    }

    /// ESPN's scoreboard lists live + scheduled + final games mixed together.
    /// We want the first one that's currently playing. Match on the status
    /// string ESPN returns (e.g. "In Progress", "Halftime", "1st Half", "2nd
    /// Quarter") and reject "Final" / "Scheduled" / "Postponed".
    private static func pickInProgress(from games: [Game]) -> Game? {
        let rejects = ["final", "schedul", "postpon", "cancel", "delayed", "pre"]
        return games.first(where: { g in
            let s = g.status.lowercased()
            if rejects.contains(where: { s.contains($0) }) { return false }
            return true
        })
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
        // Always try to attach a stream so plays flow from the moment the
        // session opens. If the match carries an explicit ESPN league+game
        // id we use that; otherwise we search live scoreboards by team name.
        attachLiveStream(for: match)
    }

    /// Attach (or resume) the play-by-play stream for this match. Three paths:
    ///   1. Match has leagueKey + gameId — stream that game directly.
    ///   2. Match has team names — scan leagues matching the sport for a
    ///      currently-playing game whose teams match.
    ///   3. Neither applies — stop any stale stream so the new session isn't
    ///      polluted by plays from a previous match.
    ///
    /// Writes plays to
    /// `~/Library/Application Support/BroadcastBrain/playbyplay/<league>/<gameId>.json`
    /// via PlayByPlayKit's LiveSession cache as polling proceeds.
    func attachLiveStream(for match: Match) {
        // 1. Explicit selection wins.
        if let leagueKey = match.leagueKey,
           let gameId = match.gameId,
           let league = PlayByPlayKit.League.all.first(where: { $0.key == leagueKey }) {
            if playByPlayStore.selectedGame?.id == gameId, playByPlayStore.isStreaming {
                print("[pbp] stream already active for \(league.displayName) \(gameId)")
                return
            }
            playByPlayStore.selectLeague(league)
            Task { @MainActor in
                await playByPlayStore.loadLiveGames()
                if let game = playByPlayStore.games.first(where: { $0.id == gameId }) {
                    playByPlayStore.startStreaming(game)
                    print("[pbp] attached explicit game \(league.displayName) — \(game.shortName)")
                } else {
                    print("[pbp] explicit gameId \(gameId) not in \(league.displayName) scoreboard; searching by team")
                    await searchAndStream(for: match)
                }
            }
            return
        }

        // 2. Search leagues that match this match's sport.
        Task { @MainActor in
            await searchAndStream(for: match)
        }
    }

    /// Keep the old name as a thin alias so legacy callers (session restore,
    /// session switching) keep working.
    func startPlayByPlayIfNeeded(for match: Match) {
        attachLiveStream(for: match)
    }

    /// Iterate leagues whose sport matches the match's sport, call ESPN's
    /// scoreboard for each, and start streaming the first in-progress game
    /// whose team names line up with the match's homeTeam/awayTeam. Stops any
    /// stale stream when nothing matches so the new session isn't grounded on
    /// stale plays.
    private func searchAndStream(for match: Match) async {
        let candidateLeagues = Self.leaguesMatchingSport(match.sport)
        let home = match.homeTeam.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let away = match.awayTeam.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let haveNames = !home.isEmpty && !away.isEmpty

        for league in candidateLeagues {
            do {
                let games = try await PlayByPlay.getLiveGames(league)
                let pick: Game?
                if haveNames {
                    pick = games.first(where: { Self.gameMatchesTeams($0, home: home, away: away) })
                        ?? Self.pickInProgress(from: games.filter { Self.gameMentionsEitherTeam($0, home: home, away: away) })
                } else {
                    pick = Self.pickInProgress(from: games)
                }
                if let pick {
                    playByPlayStore.selectLeague(league)
                    playByPlayStore.games = games
                    playByPlayStore.startStreaming(pick)
                    print("[pbp] attached by search \(league.displayName) — \(pick.shortName) [\(pick.status)]")
                    return
                }
            } catch {
                print("[pbp] search probe failed for \(league.key): \(error.localizedDescription)")
            }
        }

        // Nothing matched. Clear any stream that belonged to the previous
        // session so whisper prompts don't show unrelated plays.
        if playByPlayStore.isStreaming {
            print("[pbp] no live game matched \(match.title); stopping stale stream")
            playByPlayStore.stopStreaming()
            playByPlayStore.clearSelection()
        } else {
            print("[pbp] no live game matched \(match.title)")
        }
    }

    /// ESPN groups leagues by `sport` string ("soccer", "basketball", etc.).
    /// Map our `Sport` enum to the subset of `PlayByPlayKit.League.all` with
    /// the matching sport so a soccer match doesn't probe NBA scoreboards.
    private static func leaguesMatchingSport(_ sport: Sport) -> [PlayByPlayKit.League] {
        let sportString: String
        switch sport {
        case .soccer:           sportString = "soccer"
        case .basketball:       sportString = "basketball"
        case .baseball:         sportString = "baseball"
        case .americanFootball: sportString = "football"
        case .hockey:           sportString = "hockey"
        case .cricket, .rugby, .tennis, .other:
            // Not covered by our League.all list. Fall back to the full set so
            // a match with an unusual sport still gets a best-effort probe.
            return PlayByPlayKit.League.all
        }
        return PlayByPlayKit.League.all.filter { $0.sport == sportString }
    }

    private static func gameMatchesTeams(_ game: Game, home: String, away: String) -> Bool {
        let gh = game.homeTeam.lowercased()
        let ga = game.awayTeam.lowercased()
        // Either orientation — the commentator might flip home/away.
        let oriented = gh.contains(home) && ga.contains(away)
        let flipped  = gh.contains(away) && ga.contains(home)
        return oriented || flipped
    }

    private static func gameMentionsEitherTeam(_ game: Game, home: String, away: String) -> Bool {
        let gh = game.homeTeam.lowercased()
        let ga = game.awayTeam.lowercased()
        return gh.contains(home) || ga.contains(home) || gh.contains(away) || ga.contains(away)
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

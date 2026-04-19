import Foundation
import Observation
import PlayByPlayKit

struct SavedGameEntry: Identifiable, Hashable {
    let fileURL: URL
    let leagueKey: String
    let game: CompactGame
    let modifiedAt: Date
    var id: String { fileURL.path }
}

@MainActor
@Observable
final class PlayByPlayStore {
    let leagues: [League] = League.all
    var selectedLeague: League
    var games: [Game] = []
    var searchText: String = ""
    var loadingGames: Bool = false
    var gamesError: String?

    var selectedGame: Game?
    var currentCompact: CompactGame?
    var streamError: String?
    var isStreaming: Bool = false
    var lastUpdated: Date?

    var plays: [CompactPlay] {
        guard let c = currentCompact else { return [] }
        return c.periods.flatMap { $0.plays }
    }

    let cacheDirectory: URL

    private var activeSession: LiveSession?
    private var streamTask: Task<Void, Never>?

    init(cacheDirectory: URL) {
        self.cacheDirectory = cacheDirectory
        self.selectedLeague = League.all.first(where: { $0.key == "nba" }) ?? League.all[0]
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    var filteredGames: [Game] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return games }
        return games.filter { g in
            g.name.lowercased().contains(q)
                || g.shortName.lowercased().contains(q)
                || g.homeTeam.lowercased().contains(q)
                || g.awayTeam.lowercased().contains(q)
        }
    }

    func loadLiveGames() async {
        loadingGames = true
        gamesError = nil
        defer { loadingGames = false }
        do {
            let league = selectedLeague
            games = try await PlayByPlay.getLiveGames(league)
        } catch {
            games = []
            gamesError = String(describing: error)
        }
    }

    func selectLeague(_ league: League) {
        guard league != selectedLeague else { return }
        selectedLeague = league
        games = []
    }

    func startStreaming(_ game: Game) {
        stopStreaming()

        selectedGame = game
        currentCompact = nil
        streamError = nil
        isStreaming = true
        lastUpdated = nil

        let league = selectedLeague
        let cacheDir = cacheDirectory
        let session = PlayByPlay.liveSession(
            league: league,
            game: game,
            cacheDirectory: cacheDir,
            pollInterval: 0.5,
            maxConsecutiveTransientFailures: 20,
            onTransientError: nil
        )
        activeSession = session

        streamTask = Task { [weak self] in
            await session.start()
            let stream = await session.deltas
            do {
                for try await delta in stream {
                    await MainActor.run {
                        guard let self else { return }
                        self.currentCompact = delta.state
                        self.lastUpdated = Date()
                    }
                    if Task.isCancelled { break }
                }
            } catch {
                await MainActor.run {
                    self?.streamError = String(describing: error)
                    self?.isStreaming = false
                }
            }
            await MainActor.run {
                self?.isStreaming = false
            }
        }
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        if let session = activeSession {
            Task { await session.stop() }
        }
        activeSession = nil
        isStreaming = false
    }

    func clearSelection() {
        stopStreaming()
        selectedGame = nil
        currentCompact = nil
        streamError = nil
        lastUpdated = nil
    }

    func listSavedGames() -> [SavedGameEntry] {
        let fm = FileManager.default
        guard let leagueDirs = try? fm.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        let decoder = JSONDecoder()
        var entries: [SavedGameEntry] = []
        for dir in leagueDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            guard let files = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }
            for file in files where file.pathExtension == "json" && !file.lastPathComponent.hasPrefix(".") {
                guard let data = try? Data(contentsOf: file),
                      let game = try? decoder.decode(CompactGame.self, from: data) else { continue }
                let mtime = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                entries.append(SavedGameEntry(
                    fileURL: file,
                    leagueKey: dir.lastPathComponent,
                    game: game,
                    modifiedAt: mtime
                ))
            }
        }
        return entries.sorted { $0.modifiedAt > $1.modifiedAt }
    }
}

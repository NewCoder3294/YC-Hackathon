import Foundation

public enum PlayByPlay {
    public static var leagues: [League] { League.all }

    public static func getLiveGames(_ league: League, session: URLSession = .shared) async throws -> [Game] {
        let client = ESPNClient(session: session)
        let response: ScoreboardResponse = try await client.fetchJSON(ESPNEndpoints.scoreboardURL(league))
        return Scoreboard.toGames(response)
    }

    public static func getPlays(_ league: League, game: Game, session: URLSession = .shared) async throws -> CompactGame {
        let client = ESPNClient(session: session)
        let fetcher = PlaysFetcher(client: client)
        let rawPlays = try await fetcher.fetchRawPlays(league: league, gameId: game.id)
        let cache = AthleteCache()
        await fetcher.resolveAthletes(for: rawPlays, cache: cache)
        let map = await cache.snapshot()
        return Compactor.compactGame(league: league, game: game, rawPlays: rawPlays, athleteMap: map)
    }

    public static func liveSession(
        league: League,
        game: Game,
        cacheDirectory: URL,
        pollInterval: TimeInterval = 10,
        maxConsecutiveTransientFailures: Int = 10,
        onTransientError: (@Sendable (Error) -> Void)? = nil,
        session: URLSession = .shared
    ) -> LiveSession {
        LiveSession(
            league: league,
            game: game,
            cacheDirectory: cacheDirectory,
            pollInterval: pollInterval,
            maxConsecutiveTransientFailures: maxConsecutiveTransientFailures,
            onTransientError: onTransientError,
            session: session
        )
    }
}

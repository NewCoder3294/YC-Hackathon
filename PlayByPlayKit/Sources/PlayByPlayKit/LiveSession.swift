import Foundation

public actor LiveSession {
    private let league: League
    private let game: Game
    private let cacheDirectory: URL
    private let pollInterval: TimeInterval
    private let maxConsecutiveTransientFailures: Int
    private let onTransientError: (@Sendable (Error) -> Void)?
    private let client: ESPNClient
    private let fetcher: PlaysFetcher
    private let athleteCache = AthleteCache()

    private var state: CompactGame?
    private var pollTask: Task<Void, Never>?
    private var continuation: AsyncThrowingStream<PlayDelta, Error>.Continuation?
    private var stream: AsyncThrowingStream<PlayDelta, Error>?
    private var consecutiveFailures: Int = 0
    private var started = false

    init(
        league: League,
        game: Game,
        cacheDirectory: URL,
        pollInterval: TimeInterval,
        maxConsecutiveTransientFailures: Int,
        onTransientError: (@Sendable (Error) -> Void)?,
        session: URLSession
    ) {
        self.league = league
        self.game = game
        self.cacheDirectory = cacheDirectory
        self.pollInterval = pollInterval
        self.maxConsecutiveTransientFailures = maxConsecutiveTransientFailures
        self.onTransientError = onTransientError
        self.client = ESPNClient(session: session)
        self.fetcher = PlaysFetcher(client: client)
    }

    public nonisolated var deltas: AsyncThrowingStream<PlayDelta, Error> {
        get async {
            await makeStreamIfNeeded()
        }
    }

    private func makeStreamIfNeeded() -> AsyncThrowingStream<PlayDelta, Error> {
        if let stream { return stream }
        let (s, cont) = AsyncThrowingStream<PlayDelta, Error>.makeStream()
        self.stream = s
        self.continuation = cont
        cont.onTermination = { [weak self] _ in
            Task { [weak self] in await self?.stop() }
        }
        return s
    }

    public func currentState() -> CompactGame? { state }

    public func start() async {
        guard !started else { return }
        started = true
        _ = makeStreamIfNeeded()

        // Seed from disk if present.
        let url = SessionStorage.cacheFileURL(
            root: cacheDirectory,
            leagueKey: league.key,
            shortName: game.shortName
        )
        if let disk = try? SessionStorage.read(url) {
            self.state = disk
            await athleteCache.seed(disk.athletes)
        }

        pollTask = Task { [weak self] in
            await self?.pollLoop(cacheURL: url)
        }
    }

    public func stop() async {
        pollTask?.cancel()
        pollTask = nil
        continuation?.finish()
        continuation = nil
    }

    private func pollLoop(cacheURL: URL) async {
        while !Task.isCancelled {
            await tickOnce(cacheURL: cacheURL)
            if Task.isCancelled { return }
            if pollTask == nil { return }
            do {
                try await cancellableSleep(pollInterval)
            } catch {
                return
            }
        }
    }

    private func tickOnce(cacheURL: URL) async {
        do {
            let rawPlays = try await fetcher.fetchRawPlays(league: league, gameId: game.id)
            await fetcher.resolveAthletes(for: rawPlays, cache: athleteCache)
            let resolvedMap = await athleteCache.snapshot()
            let newCompact = Compactor.compactGame(
                league: league,
                game: game,
                rawPlays: rawPlays,
                athleteMap: resolvedMap
            )
            let newPlays = Compactor.diffNewPlays(prev: state, next: newCompact)
            if !newPlays.isEmpty || state == nil {
                state = newCompact
                try SessionStorage.write(newCompact, to: cacheURL)
                continuation?.yield(PlayDelta(newPlays: newPlays, state: newCompact))
            }
            consecutiveFailures = 0
        } catch {
            if isPermanent(error) {
                continuation?.finish(throwing: error)
                pollTask?.cancel()
                pollTask = nil
                return
            }
            consecutiveFailures += 1
            onTransientError?(error)
            if consecutiveFailures >= maxConsecutiveTransientFailures {
                continuation?.finish(throwing: error)
                pollTask?.cancel()
                pollTask = nil
            }
        }
    }

    private func cancellableSleep(_ seconds: TimeInterval) async throws {
        let nanos = UInt64(max(0, seconds) * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanos)
    }

    private func isPermanent(_ error: Error) -> Bool {
        if let e = error as? PlayByPlayError {
            switch e {
            case .http(let status, _):
                return (400..<500).contains(status)
            case .decoding, .invalidAthleteRef:
                return true
            case .io, .cancelled:
                return false
            }
        }
        return false
    }
}

import Foundation

actor AthleteCache {
    private var entries: [String: AthleteResponse] = [:]

    func get(_ url: String) -> AthleteResponse? { entries[url] }

    func set(_ url: String, _ value: AthleteResponse) { entries[url] = value }

    func has(_ url: String) -> Bool { entries[url] != nil }

    func snapshot() -> [String: AthleteResponse] { entries }

    func seed(_ athletes: [String: Athlete]) {
        // Seed cache with already-known athletes so we don't refetch.
        // Keyed by the original $ref URL, which we don't have here —
        // so we key by athleteId URL shape that `extractId` recovers.
        // Instead of reconstructing URLs, we just record the IDs as already-known;
        // the fetcher filters its $ref list by ID when the map knows that ID.
        for (id, a) in athletes {
            // Use synthetic key "id:<id>" so fetcher can check by ID.
            entries["id:\(id)"] = AthleteResponse(
                id: id,
                displayName: a.name,
                fullName: a.name,
                jersey: a.jersey,
                position: a.position.map { AthleteResponse.Position(abbreviation: $0, displayName: $0) }
            )
        }
    }

    func hasId(_ id: String) -> Bool { entries["id:\(id)"] != nil }

    func byId(_ id: String) -> AthleteResponse? { entries["id:\(id)"] }
}

struct PlaysFetcher {
    let client: ESPNClient

    init(client: ESPNClient = ESPNClient()) {
        self.client = client
    }

    func fetchRawPlays(league: League, gameId: String) async throws -> [RawPlay] {
        let url = ESPNEndpoints.playByPlayURL(league, gameId: gameId)
        let response: PlayByPlayResponse = try await client.fetchJSON(url)
        return response.items ?? []
    }

    /// Resolve every athlete $ref into the cache. Concurrency bounded to `maxInFlight`.
    func resolveAthletes(for plays: [RawPlay], cache: AthleteCache, maxInFlight: Int = 8) async {
        var unique = Set<String>()
        for play in plays {
            for p in play.participants ?? [] {
                if let ref = p.athlete?.ref, !ref.isEmpty {
                    unique.insert(ref)
                }
            }
        }

        var toFetch: [String] = []
        for ref in unique {
            if await cache.has(ref) { continue }
            if let id = ESPNRef.extractId(from: ref), await cache.hasId(id) { continue }
            toFetch.append(ref)
        }

        guard !toFetch.isEmpty else { return }

        await withTaskGroup(of: (String, AthleteResponse?).self) { group in
            var index = 0
            var active = 0

            func launchNext() {
                guard index < toFetch.count else { return }
                let ref = toFetch[index]
                index += 1
                active += 1
                group.addTask {
                    guard let url = URL(string: ref) else { return (ref, nil) }
                    let response: AthleteResponse? = try? await self.client.fetchJSON(url)
                    return (ref, response)
                }
            }

            let initial = min(maxInFlight, toFetch.count)
            for _ in 0..<initial {
                launchNext()
            }

            for await (ref, response) in group {
                active -= 1
                if let response {
                    await cache.set(ref, response)
                    if let id = response.id {
                        await cache.set("id:\(id)", response)
                    }
                }
                launchNext()
            }
            _ = active
        }
    }
}

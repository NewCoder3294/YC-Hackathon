import Foundation
import Observation

@Observable
final class SessionStore {
    private(set) var sessions: [Session] = []
    private let storageDir: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(storageDir: URL? = nil) {
        let dir = storageDir ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BroadcastBrain/sessions", isDirectory: true)
        self.storageDir = dir

        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = e

        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        self.decoder = d

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.sessions = loadAllFromDisk().sorted { $0.createdAt > $1.createdAt }

        if self.sessions.isEmpty {
            seedFixtures()
        }
    }

    func save(_ session: Session) {
        let url = storageDir.appendingPathComponent("\(session.id.uuidString).json")
        do {
            try encoder.encode(session).write(to: url, options: .atomic)
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx] = session
            } else {
                sessions.insert(session, at: 0)
            }
        } catch {
            print("SessionStore save failed: \(error)")
        }
    }

    func delete(_ session: Session) {
        let url = storageDir.appendingPathComponent("\(session.id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
        sessions.removeAll { $0.id == session.id }
    }

    private func loadAllFromDisk() -> [Session] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: storageDir, includingPropertiesForKeys: nil
        ) else { return [] }
        return urls.compactMap { url in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let session = try? decoder.decode(Session.self, from: data)
            else { return nil }
            return session
        }
    }

    private func seedFixtures() {
        let now = Date()
        let aWeekAgo = now.addingTimeInterval(-86_400 * 7)
        let twoWeeksAgo = now.addingTimeInterval(-86_400 * 14)

        let s1 = Session(
            createdAt: aWeekAgo,
            title: "Brighton vs Arsenal · prep run",
            transcript: "Saka cut inside from the right… White overlapping behind him… Rice recoveries trigger Arsenal's high press…",
            notes: "Press triggers: Rice recoveries, Ødegaard turnovers in midfield.\n\nSaka form: 3 goals in his last 4 apps vs Brighton.",
            statCards: [
                StatCard(
                    timestamp: aWeekAgo, player: "Bukayo Saka",
                    statValue: "3 in 4",
                    contextLine: "Goals in his last 4 apps vs Brighton",
                    rawTranscript: "Saka again on the right", latencyMs: 420
                ),
                StatCard(
                    timestamp: aWeekAgo.addingTimeInterval(1200), player: "Declan Rice",
                    statValue: "7 recoveries",
                    contextLine: "Most in a single half this PL season",
                    rawTranscript: "Rice wins it back again", latencyMs: 385
                )
            ],
            researchMessages: [
                ChatMessage(role: .user, content: "How do Brighton usually press high-line full-backs?", grounded: false),
                ChatMessage(role: .assistant, content: "Brighton triggers their press on opposition CB touches toward the full-back. Estupiñán aggressively squeezes the touchline; Mitoma tracks inside. Watch for Saka pulling wide to bait that trigger.", grounded: true)
            ]
        )
        let s2 = Session(
            createdAt: twoWeeksAgo,
            title: "Liverpool vs City · rehearsal",
            transcript: "Salah on the break… Rodri holds the middle… Alisson long kick finds Diogo…",
            notes: "xG differential is the story.\nCity press high — Liverpool's direct play threatens.",
            statCards: [],
            researchMessages: []
        )
        save(s1); save(s2)
    }
}

import Foundation

enum SessionStorage {
    static func cacheFileURL(root: URL, leagueKey: String, shortName: String, date: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateStr = formatter.string(from: date)
        let sanitized = shortName.replacingOccurrences(of: " ", with: "_")
        let leagueDir = root.appendingPathComponent(leagueKey, isDirectory: true)
        return leagueDir.appendingPathComponent("\(sanitized)_\(dateStr).json")
    }

    static func read(_ url: URL) throws -> CompactGame? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CompactGame.self, from: data)
        } catch {
            throw PlayByPlayError(io: error)
        }
    }

    static func write(_ game: CompactGame, to url: URL) throws {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(game)

            let tempURL = url.deletingLastPathComponent()
                .appendingPathComponent(".\(url.lastPathComponent).tmp")
            try data.write(to: tempURL, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: url)
            }
        } catch {
            throw PlayByPlayError(io: error)
        }
    }
}

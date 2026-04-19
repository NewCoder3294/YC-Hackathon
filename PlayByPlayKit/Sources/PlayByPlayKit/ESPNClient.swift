import Foundation

struct ESPNClient: Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchJSON<T: Decodable>(_ url: URL, as type: T.Type = T.self) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw error
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw PlayByPlayError.http(status: http.statusCode, url: url)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PlayByPlayError(decoding: error, context: url.absoluteString)
        }
    }
}

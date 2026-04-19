import Foundation

struct ESPNClient: Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchJSON<T: Decodable>(_ url: URL, as type: T.Type = T.self) async throws -> T {
        // ESPN returns `$ref` URLs over `http://`, which ATS blocks by default.
        // Every ESPN endpoint is reachable over HTTPS, so upgrade the scheme
        // transparently rather than loosening ATS app-wide.
        let requestURL = Self.upgradeToHTTPS(url)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: requestURL)
        } catch {
            throw error
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw PlayByPlayError.http(status: http.statusCode, url: requestURL)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PlayByPlayError(decoding: error, context: requestURL.absoluteString)
        }
    }

    static func upgradeToHTTPS(_ url: URL) -> URL {
        guard url.scheme?.lowercased() == "http",
              var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }
        comps.scheme = "https"
        return comps.url ?? url
    }
}

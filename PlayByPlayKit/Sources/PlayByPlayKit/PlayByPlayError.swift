import Foundation

public enum PlayByPlayError: Error, Sendable {
    case http(status: Int, url: URL)
    case decoding(underlying: String, context: String)
    case io(underlying: String)
    case invalidAthleteRef(String)
    case cancelled

    init(decoding error: Error, context: String) {
        self = .decoding(underlying: String(describing: error), context: context)
    }

    init(io error: Error) {
        self = .io(underlying: String(describing: error))
    }
}

extension PlayByPlayError: Equatable {
    public static func == (lhs: PlayByPlayError, rhs: PlayByPlayError) -> Bool {
        switch (lhs, rhs) {
        case let (.http(a, b), .http(c, d)): return a == c && b == d
        case let (.decoding(a, b), .decoding(c, d)): return a == c && b == d
        case let (.io(a), .io(b)): return a == b
        case let (.invalidAthleteRef(a), .invalidAthleteRef(b)): return a == b
        case (.cancelled, .cancelled): return true
        default: return false
        }
    }
}

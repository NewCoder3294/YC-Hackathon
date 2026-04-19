import Foundation

public struct Coordinate: Hashable, Sendable, Codable {
    public let x: Double?
    public let y: Double?
    public init(x: Double?, y: Double?) {
        self.x = x
        self.y = y
    }
}

public struct PitchCount: Hashable, Sendable, Codable {
    public let balls: Int?
    public let strikes: Int?
    public init(balls: Int?, strikes: Int?) {
        self.balls = balls
        self.strikes = strikes
    }
}

public struct DriveMarker: Hashable, Sendable, Codable {
    public let down: Int?
    public let distance: Int?
    public let yardLine: Int?
    public let yardsToEndzone: Int?
    public let downDistance: String?
    public let possession: String?
    public let teamId: String?
}

public struct TeamParticipant: Hashable, Sendable, Codable {
    public let teamId: String?
    public let order: Int?
    public let type: String?
}

public struct FieldPosition: Hashable, Sendable, Codable {
    public let x: Double?
    public let y: Double?
}

public struct GoalPosition: Hashable, Sendable, Codable {
    public let x: Double?
    public let y: Double?
    public let z: Double?
}

enum ESPNRef {
    static func extractId(from url: String?) -> String? {
        guard let url else { return nil }
        guard let regex = try? NSRegularExpression(pattern: #"/(?:teams|athletes|positions)/(\d+)"#) else { return nil }
        let range = NSRange(url.startIndex..., in: url)
        guard let match = regex.firstMatch(in: url, range: range), match.numberOfRanges >= 2 else {
            return nil
        }
        guard let r = Range(match.range(at: 1), in: url) else { return nil }
        return String(url[r])
    }
}

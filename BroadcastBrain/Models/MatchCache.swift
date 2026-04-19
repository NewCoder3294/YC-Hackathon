import Foundation

struct MatchCache: Codable, Equatable {
    let matchId: String
    let title: String
    let players: [Player]
    let facts: [String]
    let storylines: [String]
}

struct Player: Codable, Equatable {
    let name: String
    let team: String
    let jersey: String
    let position: String
    let keyStats: [String: String]
}

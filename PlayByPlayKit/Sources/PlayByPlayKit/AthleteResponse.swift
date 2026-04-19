import Foundation

struct AthleteResponse: Decodable {
    let id: String?
    let displayName: String?
    let fullName: String?
    let jersey: String?
    let position: Position?

    struct Position: Decodable {
        let abbreviation: String?
        let displayName: String?
    }
}

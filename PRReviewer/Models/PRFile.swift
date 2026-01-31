import Foundation

struct PRFile: Codable, Identifiable, Equatable, Sendable {
    var id: String { sha + filename }

    let sha: String
    let filename: String
    let status: FileStatus
    let additions: Int
    let deletions: Int
    let changes: Int
    let patch: String?

    enum CodingKeys: String, CodingKey {
        case sha, filename, status, additions, deletions, changes, patch
    }
}

enum FileStatus: String, Codable, Sendable {
    case added
    case removed
    case modified
    case renamed
    case copied
    case changed
    case unchanged
}

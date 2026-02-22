import Foundation

enum DiffLineType: String, Codable, Equatable, Hashable, Sendable {
    case addition
    case deletion
    case context
    case hunkHeader
}

struct DiffLine: Identifiable, Equatable, Sendable, Codable {
    let id = UUID()
    let type: DiffLineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?

    private enum CodingKeys: String, CodingKey {
        case type, content, oldLineNumber, newLineNumber
    }
}

struct DiffHunk: Identifiable, Equatable, Sendable, Codable {
    let id = UUID()
    let header: String
    let lines: [DiffLine]

    private enum CodingKeys: String, CodingKey {
        case header, lines
    }
}

struct FileDiff: Identifiable, Equatable, Sendable, Codable {
    let id = UUID()
    let filename: String
    let status: FileStatus
    let hunks: [DiffHunk]
    let additions: Int
    let deletions: Int

    private enum CodingKeys: String, CodingKey {
        case filename, status, hunks, additions, deletions
    }
}

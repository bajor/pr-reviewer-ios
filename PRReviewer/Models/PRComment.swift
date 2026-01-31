import Foundation

struct PRComment: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let nodeId: String  // GraphQL global ID - needed for minimize mutation
    let body: String
    let user: GitHubUser
    let path: String?
    let line: Int?
    let side: String?
    let commitId: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body, user, path, line, side
        case nodeId = "node_id"
        case commitId = "commit_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayPosition: CommentPosition? {
        guard let path = path, let line = line else { return nil }
        return CommentPosition(path: path, line: line, side: side ?? "RIGHT")
    }
}

struct CommentPosition: Equatable, Hashable, Sendable {
    let path: String
    let line: Int
    let side: String
}

/// Reasons for minimizing (hiding) a comment via GitHub's GraphQL API
enum MinimizeReason: String, CaseIterable, Sendable {
    case outdated = "OUTDATED"
    case offTopic = "OFF_TOPIC"
    case spam = "SPAM"
    case resolved = "RESOLVED"
    case duplicate = "DUPLICATE"
    case abuse = "ABUSE"

    var displayName: String {
        switch self {
        case .outdated: return "Outdated"
        case .offTopic: return "Off-topic"
        case .spam: return "Spam"
        case .resolved: return "Resolved"
        case .duplicate: return "Duplicate"
        case .abuse: return "Abuse"
        }
    }
}

struct IssueComment: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let nodeId: String  // GraphQL global ID - needed for minimize mutation
    let body: String
    let user: GitHubUser
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body, user
        case nodeId = "node_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

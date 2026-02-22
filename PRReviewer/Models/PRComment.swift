import Foundation

struct PRComment: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let nodeId: String  // GraphQL global ID - needed for minimize mutation
    let body: String
    let user: GitHubUser
    let path: String?
    let line: Int?
    let side: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body, user, path, line, side
        case nodeId = "node_id"
        case createdAt = "created_at"
    }
}

/// Reasons for minimizing (hiding) a comment via GitHub's GraphQL API
enum MinimizeReason: String, CaseIterable, Sendable {
    case outdated = "OUTDATED"
    case offTopic = "OFF_TOPIC"
    case spam = "SPAM"
    case resolved = "RESOLVED"
    case duplicate = "DUPLICATE"
    case abuse = "ABUSE"
}

struct IssueComment: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let body: String
    let user: GitHubUser
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body, user
        case createdAt = "created_at"
    }
}

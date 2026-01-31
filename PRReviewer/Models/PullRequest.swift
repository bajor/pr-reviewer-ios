import Foundation

struct PullRequest: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String
    let htmlUrl: String
    let user: GitHubUser
    let head: GitRef
    let base: GitRef
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, head, base
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var repositoryFullName: String {
        base.repo?.fullName ?? "\(base.repo?.owner.login ?? "unknown")/\(base.repo?.name ?? "unknown")"
    }
}

struct GitHubUser: Codable, Equatable, Sendable {
    let id: Int
    let login: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, login
        case avatarUrl = "avatar_url"
    }
}

struct GitRef: Codable, Equatable, Sendable {
    let ref: String
    let sha: String
    let repo: Repository?
}

struct Repository: Codable, Equatable, Sendable {
    let id: Int
    let name: String
    let fullName: String
    let owner: GitHubUser

    enum CodingKeys: String, CodingKey {
        case id, name, owner
        case fullName = "full_name"
    }
}

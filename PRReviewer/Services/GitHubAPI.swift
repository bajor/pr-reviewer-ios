import Foundation

enum GitHubAPIError: Error, LocalizedError {
    case noToken
    case invalidURL
    case networkError(Error)
    case httpError(Int, String?)
    case decodingError(Error)
    case rateLimited(resetDate: Date?)
    case graphQLError(String)
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .noToken: return "No GitHub token configured"
        case .invalidURL: return "Invalid URL"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .httpError(let code, let message): return "HTTP \(code): \(message ?? "Unknown error")"
        case .decodingError(let error): return "Failed to decode response: \(error.localizedDescription)"
        case .rateLimited(let resetDate):
            if let date = resetDate {
                return "Rate limited. Resets at \(date.formatted())"
            }
            return "Rate limited"
        case .graphQLError(let message):
            return "GraphQL error: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        }
    }
}

actor GitHubAPI {
    static let baseURL = "https://api.github.com"

    private let session: URLSession
    private let decoder: JSONDecoder
    private var tokenOverride: String?

    init(token: String? = nil) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.tokenOverride = token

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    private func getToken() throws -> String {
        if let override = tokenOverride {
            return override
        }
        // Get first available token from accounts
        guard let account = AccountManager.shared.accounts.first,
              let token = KeychainManager.getToken(for: account.id) else {
            throw GitHubAPIError.noToken
        }
        return token
    }

    private func makeRequest(url: String, method: String = "GET", body: Data? = nil, accept: String = "application/vnd.github+json") async throws -> Data {
        let token = try getToken()

        guard let url = URL(string: url) else {
            throw GitHubAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubAPIError.networkError(URLError(.badServerResponse))
            }

            if httpResponse.statusCode == 403 {
                let resetTimestamp = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset")
                    .flatMap { Double($0) }
                    .map { Date(timeIntervalSince1970: $0) }
                throw GitHubAPIError.rateLimited(resetDate: resetTimestamp)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8)
                throw GitHubAPIError.httpError(httpResponse.statusCode, message)
            }

            return data
        } catch let error as GitHubAPIError {
            throw error
        } catch {
            throw GitHubAPIError.networkError(error)
        }
    }

    func searchPRs(username: String) async throws -> [PullRequest] {
        let query = "is:open is:pr involves:\(username)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = "\(Self.baseURL)/search/issues?q=\(query)&per_page=100&sort=updated&order=desc"

        let data = try await makeRequest(url: url)

        struct SearchResponse: Decodable {
            let items: [SearchItem]
        }

        struct SearchItem: Decodable {
            let id: Int
            let number: Int
            let title: String
            let body: String?
            let state: String
            let user: GitHubUser
            let createdAt: Date
            let updatedAt: Date
            let pullRequest: PRInfo?
            let repositoryUrl: String

            enum CodingKeys: String, CodingKey {
                case id, number, title, body, state, user
                case createdAt = "created_at"
                case updatedAt = "updated_at"
                case pullRequest = "pull_request"
                case repositoryUrl = "repository_url"
            }
        }

        struct PRInfo: Decodable {
            let url: String
        }

        do {
            let response = try decoder.decode(SearchResponse.self, from: data)

            var pullRequests: [PullRequest] = []
            for item in response.items where item.pullRequest != nil {
                if let pr = try? await getPullRequest(from: item.pullRequest!.url) {
                    pullRequests.append(pr)
                }
            }

            return pullRequests
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }

    private func getPullRequest(from url: String) async throws -> PullRequest {
        let data = try await makeRequest(url: url)
        do {
            return try decoder.decode(PullRequest.self, from: data)
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }

    func getPRFiles(owner: String, repo: String, number: Int) async throws -> [PRFile] {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/pulls/\(number)/files?per_page=100"
        let data = try await makeRequest(url: url)

        do {
            return try decoder.decode([PRFile].self, from: data)
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }

    func getPRComments(owner: String, repo: String, number: Int) async throws -> [PRComment] {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/pulls/\(number)/comments?per_page=100"
        let data = try await makeRequest(url: url)

        do {
            return try decoder.decode([PRComment].self, from: data)
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }

    func getIssueComments(owner: String, repo: String, number: Int) async throws -> [IssueComment] {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/issues/\(number)/comments?per_page=100"
        let data = try await makeRequest(url: url)

        do {
            return try decoder.decode([IssueComment].self, from: data)
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }

    func getPRCommits(owner: String, repo: String, number: Int) async throws -> [PRCommit] {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/pulls/\(number)/commits?per_page=100"
        let data = try await makeRequest(url: url)

        do {
            return try decoder.decode([PRCommit].self, from: data)
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }

    // MARK: - File Content

    func getFileContent(owner: String, repo: String, path: String, ref: String) async throws -> String? {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/contents/\(encodedPath)?ref=\(ref)"

        do {
            let data = try await makeRequest(url: url)

            struct FileContent: Decodable {
                let content: String?
                let encoding: String?
            }

            let fileContent = try decoder.decode(FileContent.self, from: data)

            if let content = fileContent.content, fileContent.encoding == "base64" {
                // Remove newlines from base64 and decode
                let cleanBase64 = content.replacingOccurrences(of: "\n", with: "")
                if let decodedData = Data(base64Encoded: cleanBase64),
                   let decodedString = String(data: decodedData, encoding: .utf8) {
                    return decodedString
                }
            }
            return nil
        } catch {
            // File might not exist (new file) or other error
            return nil
        }
    }

    // MARK: - Comment Creation

    func createReviewComment(owner: String, repo: String, number: Int, body: String, path: String, line: Int, commitId: String) async throws {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/pulls/\(number)/comments"

        let payload: [String: Any] = [
            "body": body,
            "commit_id": commitId,
            "path": path,
            "line": line,
            "side": "RIGHT"
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        _ = try await makeRequest(url: url, method: "POST", body: jsonData)
    }

    func replyToComment(owner: String, repo: String, number: Int, commentId: Int, body: String) async throws {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/pulls/\(number)/comments/\(commentId)/replies"

        let payload = ["body": body]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        _ = try await makeRequest(url: url, method: "POST", body: jsonData)
    }

    func createIssueComment(owner: String, repo: String, number: Int, body: String) async throws {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/issues/\(number)/comments"

        let payload = ["body": body]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        _ = try await makeRequest(url: url, method: "POST", body: jsonData)
    }

    func deleteIssueComment(owner: String, repo: String, commentId: Int) async throws {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/issues/comments/\(commentId)"
        _ = try await makeRequest(url: url, method: "DELETE", body: nil)
    }

    // MARK: - Check Runs & Status

    /// Get combined check status for a commit (GitHub Actions, etc.)
    func getCheckRuns(owner: String, repo: String, ref: String) async throws -> CheckRunsStatus {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/commits/\(ref)/check-runs"
        let data = try await makeRequest(url: url)

        struct CheckRunsResponse: Decodable {
            let totalCount: Int
            let checkRuns: [CheckRun]

            enum CodingKeys: String, CodingKey {
                case totalCount = "total_count"
                case checkRuns = "check_runs"
            }
        }

        struct CheckRun: Decodable {
            let id: Int
            let name: String
            let status: String  // queued, in_progress, completed
            let conclusion: String?  // success, failure, neutral, cancelled, skipped, timed_out, action_required, null
        }

        do {
            let response = try decoder.decode(CheckRunsResponse.self, from: data)

            let total = response.totalCount
            let successful = response.checkRuns.filter { $0.conclusion == "success" || $0.conclusion == "skipped" || $0.conclusion == "neutral" }.count
            let failed = response.checkRuns.filter { $0.conclusion == "failure" || $0.conclusion == "timed_out" }.count
            let pending = response.checkRuns.filter { $0.status != "completed" }.count

            return CheckRunsStatus(
                total: total,
                successful: successful,
                failed: failed,
                pending: pending
            )
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }

    /// Compare two branches to check if PR branch is behind base
    func compareBranches(owner: String, repo: String, base: String, head: String) async throws -> BranchComparison {
        let url = "\(Self.baseURL)/repos/\(owner)/\(repo)/compare/\(base)...\(head)"
        let data = try await makeRequest(url: url)

        struct CompareResponse: Decodable {
            let status: String  // ahead, behind, diverged, identical
            let aheadBy: Int
            let behindBy: Int

            enum CodingKeys: String, CodingKey {
                case status
                case aheadBy = "ahead_by"
                case behindBy = "behind_by"
            }
        }

        do {
            let response = try decoder.decode(CompareResponse.self, from: data)
            return BranchComparison(
                status: response.status,
                behindBy: response.behindBy
            )
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }

    // MARK: - Validation

    func validateToken() async throws -> String {
        let url = "\(Self.baseURL)/user"
        let data = try await makeRequest(url: url)

        struct UserResponse: Decodable {
            let login: String
        }

        do {
            let user = try decoder.decode(UserResponse.self, from: data)
            return user.login
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }

    // MARK: - GraphQL API

    private func makeGraphQLRequest(query: String, variables: [String: Any]? = nil) async throws -> [String: Any] {
        let token = try getToken()
        let url = "\(Self.baseURL)/graphql"

        guard let requestURL = URL(string: url) else {
            throw GitHubAPIError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["query": query]
        if let variables = variables {
            body["variables"] = variables
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubAPIError.networkError(URLError(.badServerResponse))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8)
                throw GitHubAPIError.httpError(httpResponse.statusCode, message)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw GitHubAPIError.decodingError(NSError(domain: "GraphQL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"]))
            }

            // Check for GraphQL errors
            if let errors = json["errors"] as? [[String: Any]], let firstError = errors.first {
                let message = firstError["message"] as? String ?? "Unknown GraphQL error"
                throw GitHubAPIError.graphQLError(message)
            }

            return json
        } catch let error as GitHubAPIError {
            throw error
        } catch {
            throw GitHubAPIError.networkError(error)
        }
    }

    /// Fetch review threads for a PR (needed for resolve/unresolve operations)
    /// Also returns minimized comment IDs so we can filter them out
    func getReviewThreads(owner: String, repo: String, number: Int) async throws -> ([ReviewThread], Set<Int>) {
        var allThreads: [ReviewThread] = []
        var allMinimizedIds = Set<Int>()
        var threadsCursor: String? = nil
        var hasNextThreadsPage = true

        while hasNextThreadsPage {
            let query = """
            query($owner: String!, $repo: String!, $number: Int!, $cursor: String) {
              repository(owner: $owner, name: $repo) {
                pullRequest(number: $number) {
                  reviewThreads(first: 100, after: $cursor) {
                    pageInfo {
                      endCursor
                      hasNextPage
                    }
                    nodes {
                      id
                      isResolved
                      viewerCanResolve
                      viewerCanUnresolve
                      comments(first: 100) {
                        pageInfo {
                          endCursor
                          hasNextPage
                        }
                        nodes {
                          databaseId
                          isMinimized
                        }
                      }
                    }
                  }
                }
              }
            }
            """

            var variables: [String: Any] = [
                "owner": owner,
                "repo": repo,
                "number": number
            ]
            if let cursor = threadsCursor {
                variables["cursor"] = cursor
            }

            let json = try await makeGraphQLRequest(query: query, variables: variables)

            // Parse the response
            guard let data = json["data"] as? [String: Any],
                  let repository = data["repository"] as? [String: Any],
                  let pullRequest = repository["pullRequest"] as? [String: Any],
                  let reviewThreadsConnection = pullRequest["reviewThreads"] as? [String: Any],
                  let nodes = reviewThreadsConnection["nodes"] as? [[String: Any]],
                  let pageInfo = reviewThreadsConnection["pageInfo"] as? [String: Any] else {
                break // Stop if parsing fails
            }

            // Update thread pagination state
            threadsCursor = pageInfo["endCursor"] as? String
            hasNextThreadsPage = pageInfo["hasNextPage"] as? Bool ?? false
            
            // Process each thread from the page
            for node in nodes {
                guard let id = node["id"] as? String,
                      let isResolved = node["isResolved"] as? Bool,
                      let viewerCanResolve = node["viewerCanResolve"] as? Bool,
                      let viewerCanUnresolve = node["viewerCanUnresolve"] as? Bool,
                      let commentsConnection = node["comments"] as? [String: Any],
                      let firstPageCommentNodes = commentsConnection["nodes"] as? [[String: Any]] else {
                    continue
                }
                
                var allCommentNodes = firstPageCommentNodes
                var commentPageInfo = commentsConnection["pageInfo"] as? [String: Any]
                var hasNextCommentPage = commentPageInfo?["hasNextPage"] as? Bool ?? false
                var commentCursor = commentPageInfo?["endCursor"] as? String
                
                // Paginate through all comments for this specific thread if needed
                while hasNextCommentPage {
                    let (nextPageNodes, nextPageInfo) = try await fetchMoreComments(threadNodeId: id, after: commentCursor)
                    allCommentNodes.append(contentsOf: nextPageNodes)
                    
                    hasNextCommentPage = nextPageInfo?["hasNextPage"] as? Bool ?? false
                    commentCursor = nextPageInfo?["endCursor"] as? String
                }

                var commentIds: [Int] = []
                for commentNode in allCommentNodes {
                    if let dbId = commentNode["databaseId"] as? Int {
                        commentIds.append(dbId)
                        if let isMinimized = commentNode["isMinimized"] as? Bool, isMinimized {
                            allMinimizedIds.insert(dbId)
                        }
                    }
                }

                let thread = ReviewThread(
                    id: id,
                    isResolved: isResolved,
                    viewerCanResolve: viewerCanResolve,
                    viewerCanUnresolve: viewerCanUnresolve,
                    commentIds: commentIds
                )
                allThreads.append(thread)
            }
        }

        return (allThreads, allMinimizedIds)
    }

    /// Helper to fetch subsequent pages of comments for a single review thread.
    private func fetchMoreComments(threadNodeId: String, after cursor: String?) async throws -> (nodes: [[String: Any]], pageInfo: [String: Any]?) {
        let query = """
        query($threadNodeId: ID!, $commentCursor: String) {
            node(id: $threadNodeId) {
                ... on PullRequestReviewThread {
                    comments(first: 100, after: $commentCursor) {
                        pageInfo {
                            endCursor
                            hasNextPage
                        }
                        nodes {
                            databaseId
                            isMinimized
                        }
                    }
                }
            }
        }
        """
        
        var variables: [String: Any] = ["threadNodeId": threadNodeId]
        if let cursor = cursor {
            variables["commentCursor"] = cursor
        }
        
        let json = try await makeGraphQLRequest(query: query, variables: variables)
        
        guard let data = json["data"] as? [String: Any],
              let node = data["node"] as? [String: Any],
              let commentsConnection = node["comments"] as? [String: Any],
              let nodes = commentsConnection["nodes"] as? [[String: Any]],
              let pageInfo = commentsConnection["pageInfo"] as? [String: Any] else {
            return ([], nil)
        }
        
        return (nodes, pageInfo)
    }

    /// Resolve a review thread
    func resolveReviewThread(threadId: String) async throws {
        let mutation = """
        mutation($threadId: ID!) {
          resolveReviewThread(input: { threadId: $threadId }) {
            thread {
              id
              isResolved
            }
          }
        }
        """

        let variables: [String: Any] = ["threadId": threadId]
        _ = try await makeGraphQLRequest(query: mutation, variables: variables)
    }

    /// Unresolve a review thread
    func unresolveReviewThread(threadId: String) async throws {
        let mutation = """
        mutation($threadId: ID!) {
          unresolveReviewThread(input: { threadId: $threadId }) {
            thread {
              id
              isResolved
            }
          }
        }
        """

        let variables: [String: Any] = ["threadId": threadId]
        _ = try await makeGraphQLRequest(query: mutation, variables: variables)
    }

    /// Minimize (hide) a comment
    func minimizeComment(nodeId: String, reason: MinimizeReason) async throws {
        let mutation = """
        mutation($subjectId: ID!, $classifier: ReportedContentClassifiers!) {
          minimizeComment(input: { subjectId: $subjectId, classifier: $classifier }) {
            minimizedComment {
              isMinimized
              minimizedReason
            }
          }
        }
        """

        let variables: [String: Any] = [
            "subjectId": nodeId,
            "classifier": reason.rawValue
        ]
        _ = try await makeGraphQLRequest(query: mutation, variables: variables)
    }
}

/// GitHub Actions check runs status summary
struct CheckRunsStatus: Sendable, Codable {
    let total: Int
    let successful: Int
    let failed: Int
    let pending: Int

    var overallStatus: CheckStatus {
        if total == 0 { return .none }
        if failed > 0 { return .failed }
        if pending > 0 { return .pending }
        if successful == total { return .passed }
        return .pending
    }

    enum CheckStatus: String, Codable {
        case none
        case pending
        case passed
        case failed

        var icon: String {
            switch self {
            case .none: return "circle.slash"
            case .pending: return "clock.arrow.circlepath"
            case .passed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
    }
}

/// Branch comparison result
struct BranchComparison: Sendable, Codable {
    let status: String  // ahead, behind, diverged, identical
    let behindBy: Int

    var isBehind: Bool {
        behindBy > 0
    }

    var statusLabel: String {
        if behindBy == 0 { return "Up to date" }
        if behindBy == 1 { return "1 commit behind" }
        return "\(behindBy) commits behind"
    }
}

struct PRCommit: Codable, Identifiable, Sendable {
    var id: String { sha }
    let sha: String
    let commit: CommitInfo
    let author: GitHubUser?

    struct CommitInfo: Codable, Sendable {
        let message: String
        let author: CommitAuthor?
    }

    struct CommitAuthor: Codable, Sendable {
        let name: String
        let email: String
        let date: Date
    }
}

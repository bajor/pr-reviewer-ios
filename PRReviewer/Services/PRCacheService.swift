import Foundation

/// Thread-safe in-memory cache for PR data with TTL-based expiration.
/// Reduces network calls by caching PR lists, details, and file content.
actor PRCacheService {
    static let shared = PRCacheService()

    // MARK: - Cache Entry Wrapper

    struct CacheEntry<T> {
        let data: T
        let timestamp: Date
        let ttl: TimeInterval

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }

        var age: TimeInterval {
            Date().timeIntervalSince(timestamp)
        }
    }

    // MARK: - PR Details Bundle

    struct PRDetails {
        let fileDiffs: [FileDiff]
        let comments: [PRComment]
        let issueComments: [IssueComment]
        let reviewThreads: [ReviewThread]
        let minimizedCommentIds: Set<Int>
        let checkRunsStatus: CheckRunsStatus?
        let branchComparison: BranchComparison?
    }

    // MARK: - TTL Configuration (in seconds)

    enum TTL {
        static let prList: TimeInterval = 120        // 2 minutes
        static let prDetails: TimeInterval = 300     // 5 minutes
        static let comments: TimeInterval = 120      // 2 minutes
        static let fileContent: TimeInterval = 600   // 10 minutes
        static let reviewThreads: TimeInterval = 120 // 2 minutes
    }

    // MARK: - Cache Storage

    private var prList: CacheEntry<[PullRequest]>?
    private var prDetails: [Int: CacheEntry<PRDetails>] = [:]
    private var fileContents: [String: CacheEntry<String>] = [:]

    private init() {}

    // MARK: - PR List Cache

    func getPRList() -> [PullRequest]? {
        guard let entry = prList, !entry.isExpired else {
            return nil
        }
        return entry.data
    }

    func setPRList(_ prs: [PullRequest]) {
        prList = CacheEntry(data: prs, timestamp: Date(), ttl: TTL.prList)
    }

    func invalidatePRList() {
        prList = nil
    }

    // MARK: - PR Details Cache

    func getPRDetails(for prId: Int) -> PRDetails? {
        guard let entry = prDetails[prId], !entry.isExpired else {
            return nil
        }
        return entry.data
    }

    func setPRDetails(_ details: PRDetails, for prId: Int) {
        prDetails[prId] = CacheEntry(data: details, timestamp: Date(), ttl: TTL.prDetails)
    }

    func invalidatePRDetails(for prId: Int) {
        prDetails.removeValue(forKey: prId)
    }

    func hasPRDetails(for prId: Int) -> Bool {
        guard let entry = prDetails[prId] else { return false }
        return !entry.isExpired
    }

    // MARK: - File Content Cache

    /// Get cached file content
    /// - Parameter key: Format: "owner/repo/path@ref"
    func getFileContent(key: String) -> String? {
        guard let entry = fileContents[key], !entry.isExpired else {
            return nil
        }
        return entry.data
    }

    func setFileContent(_ content: String, key: String) {
        fileContents[key] = CacheEntry(data: content, timestamp: Date(), ttl: TTL.fileContent)
    }

    static func fileContentKey(owner: String, repo: String, path: String, ref: String) -> String {
        "\(owner)/\(repo)/\(path)@\(ref)"
    }

    // MARK: - Partial Updates (for when comments/threads change)

    func updateComments(_ comments: [PRComment], issueComments: [IssueComment], for prId: Int) {
        guard var entry = prDetails[prId] else { return }
        let updatedDetails = PRDetails(
            fileDiffs: entry.data.fileDiffs,
            comments: comments,
            issueComments: issueComments,
            reviewThreads: entry.data.reviewThreads,
            minimizedCommentIds: entry.data.minimizedCommentIds,
            checkRunsStatus: entry.data.checkRunsStatus,
            branchComparison: entry.data.branchComparison
        )
        // Keep original timestamp for file diffs, but update data
        prDetails[prId] = CacheEntry(data: updatedDetails, timestamp: entry.timestamp, ttl: entry.ttl)
    }

    func updateReviewThreads(_ threads: [ReviewThread], minimizedIds: Set<Int>, for prId: Int) {
        guard var entry = prDetails[prId] else { return }
        let updatedDetails = PRDetails(
            fileDiffs: entry.data.fileDiffs,
            comments: entry.data.comments,
            issueComments: entry.data.issueComments,
            reviewThreads: threads,
            minimizedCommentIds: minimizedIds,
            checkRunsStatus: entry.data.checkRunsStatus,
            branchComparison: entry.data.branchComparison
        )
        prDetails[prId] = CacheEntry(data: updatedDetails, timestamp: entry.timestamp, ttl: entry.ttl)
    }

    // MARK: - Cache Management

    func invalidateAll() {
        prList = nil
        prDetails.removeAll()
        fileContents.removeAll()
    }

    func invalidateAllPRDetails() {
        prDetails.removeAll()
    }

    /// Remove expired entries to free memory
    func cleanup() {
        if let entry = prList, entry.isExpired {
            prList = nil
        }

        prDetails = prDetails.filter { !$0.value.isExpired }
        fileContents = fileContents.filter { !$0.value.isExpired }
    }

    // MARK: - Debug Info

    var stats: (prListCached: Bool, prDetailsCount: Int, fileContentsCount: Int) {
        (
            prListCached: prList != nil && !prList!.isExpired,
            prDetailsCount: prDetails.filter { !$0.value.isExpired }.count,
            fileContentsCount: fileContents.filter { !$0.value.isExpired }.count
        )
    }
}

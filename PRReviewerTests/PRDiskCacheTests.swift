import XCTest
@testable import PRReviewer

final class PRDiskCacheTests: XCTestCase {

    private var cache: PRDiskCache!
    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        cache = PRDiskCache(cacheDirectory: tempDir)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Helpers

    private func makePR(id: Int, number: Int, headSHA: String = "abc123") -> PullRequest {
        let user = GitHubUser(id: 1, login: "user", avatarUrl: nil)
        let repo = Repository(id: 1, name: "repo", fullName: "user/repo", owner: user)
        let head = GitRef(ref: "feature", sha: headSHA, repo: repo)
        let base = GitRef(ref: "main", sha: "base", repo: repo)
        return PullRequest(
            id: id, number: number, title: "PR #\(number)", body: nil,
            state: "open", htmlUrl: "https://example.com", user: user,
            head: head, base: base,
            createdAt: Date(), updatedAt: Date()
        )
    }

    private func makeSnapshot(prId: Int, prNumber: Int, headSHA: String = "abc123") -> PRSnapshot {
        let pr = makePR(id: prId, number: prNumber, headSHA: headSHA)
        return PRSnapshot(
            pullRequest: pr,
            fileDiffs: [FileDiff(filename: "test.swift", status: .modified, hunks: [], additions: 1, deletions: 0)],
            comments: [],
            issueComments: [],
            reviewThreads: [],
            minimizedCommentIds: Set(),
            checkRunsStatus: nil,
            branchComparison: nil,
            headSHA: headSHA,
            savedAt: Date()
        )
    }

    // MARK: - PR List Tests

    func testPRList_saveAndLoad() async throws {
        let prs = [makePR(id: 1, number: 10), makePR(id: 2, number: 20)]
        try await cache.savePRList(prs)
        let loaded = await cache.loadPRList()

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.count, 2)
        XCTAssertEqual(loaded?[0].id, 1)
        XCTAssertEqual(loaded?[1].id, 2)
    }

    func testPRList_loadWhenEmpty_returnsNil() async {
        let loaded = await cache.loadPRList()
        XCTAssertNil(loaded)
    }

    // MARK: - Snapshot Tests

    func testSnapshot_saveAndLoad() async throws {
        let snapshot = makeSnapshot(prId: 42, prNumber: 10)
        try await cache.saveSnapshot(snapshot, for: 42)
        let loaded = await cache.loadSnapshot(for: 42)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.pullRequest.id, 42)
        XCTAssertEqual(loaded?.fileDiffs.count, 1)
        XCTAssertEqual(loaded?.headSHA, "abc123")
    }

    func testSnapshot_loadMissing_returnsNil() async {
        let loaded = await cache.loadSnapshot(for: 999)
        XCTAssertNil(loaded)
    }

    func testSnapshotHeadSHA_returnsCorrectSHA() async throws {
        let snapshot = makeSnapshot(prId: 42, prNumber: 10, headSHA: "sha256hash")
        try await cache.saveSnapshot(snapshot, for: 42)

        let sha = await cache.snapshotHeadSHA(for: 42)
        XCTAssertEqual(sha, "sha256hash")
    }

    func testSnapshotHeadSHA_missing_returnsNil() async {
        let sha = await cache.snapshotHeadSHA(for: 999)
        XCTAssertNil(sha)
    }

    func testSnapshot_overwritesExisting() async throws {
        let snapshot1 = makeSnapshot(prId: 42, prNumber: 10, headSHA: "first")
        try await cache.saveSnapshot(snapshot1, for: 42)

        let snapshot2 = makeSnapshot(prId: 42, prNumber: 10, headSHA: "second")
        try await cache.saveSnapshot(snapshot2, for: 42)

        let loaded = await cache.loadSnapshot(for: 42)
        XCTAssertEqual(loaded?.headSHA, "second")
    }

    // MARK: - Delete Tests

    func testDeleteSnapshot_removesData() async throws {
        let snapshot = makeSnapshot(prId: 42, prNumber: 10)
        try await cache.saveSnapshot(snapshot, for: 42)

        try await cache.deleteSnapshot(for: 42)

        let loaded = await cache.loadSnapshot(for: 42)
        XCTAssertNil(loaded)
        let sha = await cache.snapshotHeadSHA(for: 42)
        XCTAssertNil(sha)
    }

    func testDeleteSnapshot_nonExistent_doesNotThrow() async throws {
        try await cache.deleteSnapshot(for: 999)
    }

    // MARK: - Cleanup Tests

    func testCleanupClosedPRs_removesClosedKeepsOpen() async throws {
        try await cache.saveSnapshot(makeSnapshot(prId: 1, prNumber: 10), for: 1)
        try await cache.saveSnapshot(makeSnapshot(prId: 2, prNumber: 20), for: 2)
        try await cache.saveSnapshot(makeSnapshot(prId: 3, prNumber: 30), for: 3)

        // PR 2 is closed (not in open set)
        try await cache.cleanupClosedPRs(openPRIds: Set([1, 3]))

        XCTAssertNotNil(await cache.loadSnapshot(for: 1))
        XCTAssertNil(await cache.loadSnapshot(for: 2))
        XCTAssertNotNil(await cache.loadSnapshot(for: 3))
    }

    func testCleanupClosedPRs_emptyOpenSet_removesAll() async throws {
        try await cache.saveSnapshot(makeSnapshot(prId: 1, prNumber: 10), for: 1)
        try await cache.saveSnapshot(makeSnapshot(prId: 2, prNumber: 20), for: 2)

        try await cache.cleanupClosedPRs(openPRIds: Set())

        XCTAssertNil(await cache.loadSnapshot(for: 1))
        XCTAssertNil(await cache.loadSnapshot(for: 2))
    }

    func testCleanupClosedPRs_preservesPRListFile() async throws {
        let prs = [makePR(id: 1, number: 10)]
        try await cache.savePRList(prs)
        try await cache.saveSnapshot(makeSnapshot(prId: 1, prNumber: 10), for: 1)

        try await cache.cleanupClosedPRs(openPRIds: Set())

        // PR list file should not be affected
        let loaded = await cache.loadPRList()
        XCTAssertNotNil(loaded)
    }
}

import XCTest
@testable import PRReviewer

final class PRSnapshotTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Round-trip Tests

    func testFileDiff_encodeDecode_preservesData() throws {
        let line = DiffLine(type: .addition, content: "+hello", oldLineNumber: nil, newLineNumber: 5)
        let hunk = DiffHunk(header: "@@ -1,3 +1,4 @@", oldStart: 1, oldCount: 3, newStart: 1, newCount: 4, lines: [line])
        let diff = FileDiff(filename: "test.swift", status: .modified, hunks: [hunk], additions: 1, deletions: 0)

        let data = try encoder.encode(diff)
        let decoded = try decoder.decode(FileDiff.self, from: data)

        XCTAssertEqual(decoded.filename, "test.swift")
        XCTAssertEqual(decoded.status, .modified)
        XCTAssertEqual(decoded.additions, 1)
        XCTAssertEqual(decoded.deletions, 0)
        XCTAssertEqual(decoded.hunks.count, 1)
        XCTAssertEqual(decoded.hunks[0].header, "@@ -1,3 +1,4 @@")
        XCTAssertEqual(decoded.hunks[0].lines.count, 1)
        XCTAssertEqual(decoded.hunks[0].lines[0].type, .addition)
        XCTAssertEqual(decoded.hunks[0].lines[0].content, "+hello")
        XCTAssertEqual(decoded.hunks[0].lines[0].newLineNumber, 5)
        XCTAssertNil(decoded.hunks[0].lines[0].oldLineNumber)
    }

    func testFileDiff_decodedIdsAreFresh() throws {
        let diff = FileDiff(filename: "a.swift", status: .added, hunks: [], additions: 0, deletions: 0)
        let data = try encoder.encode(diff)
        let decoded = try decoder.decode(FileDiff.self, from: data)

        // IDs are excluded from CodingKeys, so decoded gets fresh UUIDs
        XCTAssertNotEqual(diff.id, decoded.id)
    }

    func testReviewThread_encodeDecode_preservesData() throws {
        let thread = ReviewThread(id: "PRRT_abc123", isResolved: true, viewerCanResolve: false, viewerCanUnresolve: true, commentIds: [1, 2, 3])

        let data = try encoder.encode(thread)
        let decoded = try decoder.decode(ReviewThread.self, from: data)

        XCTAssertEqual(decoded.id, "PRRT_abc123")
        XCTAssertTrue(decoded.isResolved)
        XCTAssertFalse(decoded.viewerCanResolve)
        XCTAssertTrue(decoded.viewerCanUnresolve)
        XCTAssertEqual(decoded.commentIds, [1, 2, 3])
    }

    func testCheckRunsStatus_encodeDecode_preservesData() throws {
        let status = CheckRunsStatus(total: 5, completed: 4, successful: 3, failed: 1, pending: 1)

        let data = try encoder.encode(status)
        let decoded = try decoder.decode(CheckRunsStatus.self, from: data)

        XCTAssertEqual(decoded.total, 5)
        XCTAssertEqual(decoded.completed, 4)
        XCTAssertEqual(decoded.successful, 3)
        XCTAssertEqual(decoded.failed, 1)
        XCTAssertEqual(decoded.pending, 1)
    }

    func testBranchComparison_encodeDecode_preservesData() throws {
        let comparison = BranchComparison(status: "behind", aheadBy: 0, behindBy: 3)

        let data = try encoder.encode(comparison)
        let decoded = try decoder.decode(BranchComparison.self, from: data)

        XCTAssertEqual(decoded.status, "behind")
        XCTAssertEqual(decoded.aheadBy, 0)
        XCTAssertEqual(decoded.behindBy, 3)
        XCTAssertTrue(decoded.isBehind)
    }

    func testDiffLineType_allCases_roundTrip() throws {
        let types: [DiffLineType] = [.addition, .deletion, .context, .hunkHeader]
        for type in types {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(DiffLineType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    func testPRSnapshot_encodeDecode_preservesAllFields() throws {
        let user = GitHubUser(id: 1, login: "testuser", avatarUrl: "https://example.com/avatar")
        let repo = Repository(id: 100, name: "testrepo", fullName: "testuser/testrepo", owner: user)
        let head = GitRef(ref: "feature-branch", sha: "abc123", repo: repo)
        let base = GitRef(ref: "main", sha: "def456", repo: repo)
        let pr = PullRequest(
            id: 1,
            number: 42,
            title: "Test PR",
            body: "Description",
            state: "open",
            htmlUrl: "https://github.com/test/repo/pull/42",
            user: user,
            head: head,
            base: base,
            createdAt: Date(timeIntervalSince1970: 1000000),
            updatedAt: Date(timeIntervalSince1970: 1000001)
        )

        let line = DiffLine(type: .deletion, content: "-removed", oldLineNumber: 10, newLineNumber: nil)
        let hunk = DiffHunk(header: "@@ -10,1 +10,0 @@", oldStart: 10, oldCount: 1, newStart: 10, newCount: 0, lines: [line])
        let diff = FileDiff(filename: "file.swift", status: .modified, hunks: [hunk], additions: 0, deletions: 1)

        let comment = PRComment(
            id: 100,
            nodeId: "MDEyO",
            body: "Fix this",
            user: user,
            path: "file.swift",
            line: 10,
            side: "RIGHT",
            commitId: "abc123",
            createdAt: Date(timeIntervalSince1970: 1000002),
            updatedAt: Date(timeIntervalSince1970: 1000003)
        )

        let issueComment = IssueComment(
            id: 200,
            nodeId: "IC_abc",
            body: "Looks good",
            user: user,
            createdAt: Date(timeIntervalSince1970: 1000004),
            updatedAt: Date(timeIntervalSince1970: 1000005)
        )

        let thread = ReviewThread(id: "PRRT_1", isResolved: false, viewerCanResolve: true, viewerCanUnresolve: false, commentIds: [100])
        let checkRuns = CheckRunsStatus(total: 2, completed: 2, successful: 2, failed: 0, pending: 0)
        let branchComp = BranchComparison(status: "identical", aheadBy: 0, behindBy: 0)

        let snapshot = PRSnapshot(
            pullRequest: pr,
            fileDiffs: [diff],
            comments: [comment],
            issueComments: [issueComment],
            reviewThreads: [thread],
            minimizedCommentIds: Set([50, 51]),
            checkRunsStatus: checkRuns,
            branchComparison: branchComp,
            headSHA: "abc123",
            savedAt: Date(timeIntervalSince1970: 2000000)
        )

        let data = try encoder.encode(snapshot)
        let decoded = try decoder.decode(PRSnapshot.self, from: data)

        XCTAssertEqual(decoded.pullRequest.id, 1)
        XCTAssertEqual(decoded.pullRequest.number, 42)
        XCTAssertEqual(decoded.pullRequest.title, "Test PR")
        XCTAssertEqual(decoded.fileDiffs.count, 1)
        XCTAssertEqual(decoded.fileDiffs[0].filename, "file.swift")
        XCTAssertEqual(decoded.fileDiffs[0].hunks[0].lines[0].type, .deletion)
        XCTAssertEqual(decoded.comments.count, 1)
        XCTAssertEqual(decoded.comments[0].body, "Fix this")
        XCTAssertEqual(decoded.issueComments.count, 1)
        XCTAssertEqual(decoded.issueComments[0].body, "Looks good")
        XCTAssertEqual(decoded.reviewThreads.count, 1)
        XCTAssertEqual(decoded.reviewThreads[0].id, "PRRT_1")
        XCTAssertEqual(decoded.minimizedCommentIds, Set([50, 51]))
        XCTAssertEqual(decoded.checkRunsStatus?.total, 2)
        XCTAssertEqual(decoded.branchComparison?.status, "identical")
        XCTAssertEqual(decoded.headSHA, "abc123")
    }

    func testPRSnapshot_withNilOptionals_roundTrips() throws {
        let user = GitHubUser(id: 2, login: "user", avatarUrl: nil)
        let repo = Repository(id: 200, name: "repo", fullName: "user/repo", owner: user)
        let head = GitRef(ref: "branch", sha: "aaa", repo: repo)
        let base = GitRef(ref: "main", sha: "bbb", repo: repo)
        let pr = PullRequest(
            id: 2,
            number: 1,
            title: "PR",
            body: nil,
            state: "open",
            htmlUrl: "https://example.com",
            user: user,
            head: head,
            base: base,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        let snapshot = PRSnapshot(
            pullRequest: pr,
            fileDiffs: [],
            comments: [],
            issueComments: [],
            reviewThreads: [],
            minimizedCommentIds: Set(),
            checkRunsStatus: nil,
            branchComparison: nil,
            headSHA: "aaa",
            savedAt: Date(timeIntervalSince1970: 0)
        )

        let data = try encoder.encode(snapshot)
        let decoded = try decoder.decode(PRSnapshot.self, from: data)

        XCTAssertEqual(decoded.pullRequest.id, 2)
        XCTAssertNil(decoded.checkRunsStatus)
        XCTAssertNil(decoded.branchComparison)
        XCTAssertTrue(decoded.fileDiffs.isEmpty)
    }
}

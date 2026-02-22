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
        let hunk = DiffHunk(header: "@@ -1,3 +1,4 @@", lines: [line])
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
        let status = CheckRunsStatus(total: 5, successful: 3, failed: 1, pending: 1)

        let data = try encoder.encode(status)
        let decoded = try decoder.decode(CheckRunsStatus.self, from: data)

        XCTAssertEqual(decoded.total, 5)
        XCTAssertEqual(decoded.successful, 3)
        XCTAssertEqual(decoded.failed, 1)
        XCTAssertEqual(decoded.pending, 1)
    }

    func testBranchComparison_encodeDecode_preservesData() throws {
        let comparison = BranchComparison(status: "behind", behindBy: 3)

        let data = try encoder.encode(comparison)
        let decoded = try decoder.decode(BranchComparison.self, from: data)

        XCTAssertEqual(decoded.status, "behind")
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
        let user = GitHubUser(login: "testuser")

        let line = DiffLine(type: .deletion, content: "-removed", oldLineNumber: 10, newLineNumber: nil)
        let hunk = DiffHunk(header: "@@ -10,1 +10,0 @@", lines: [line])
        let diff = FileDiff(filename: "file.swift", status: .modified, hunks: [hunk], additions: 0, deletions: 1)

        let comment = PRComment(
            id: 100,
            nodeId: "MDEyO",
            body: "Fix this",
            user: user,
            path: "file.swift",
            line: 10,
            side: "RIGHT",
            createdAt: Date(timeIntervalSince1970: 1000002)
        )

        let issueComment = IssueComment(
            id: 200,
            body: "Looks good",
            user: user,
            createdAt: Date(timeIntervalSince1970: 1000004)
        )

        let thread = ReviewThread(id: "PRRT_1", isResolved: false, viewerCanResolve: true, viewerCanUnresolve: false, commentIds: [100])
        let checkRuns = CheckRunsStatus(total: 2, successful: 2, failed: 0, pending: 0)
        let branchComp = BranchComparison(status: "identical", behindBy: 0)

        let snapshot = PRSnapshot(
            fileDiffs: [diff],
            comments: [comment],
            issueComments: [issueComment],
            reviewThreads: [thread],
            minimizedCommentIds: Set([50, 51]),
            checkRunsStatus: checkRuns,
            branchComparison: branchComp
        )

        let data = try encoder.encode(snapshot)
        let decoded = try decoder.decode(PRSnapshot.self, from: data)

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
    }

    func testPRSnapshot_withNilOptionals_roundTrips() throws {
        let snapshot = PRSnapshot(
            fileDiffs: [],
            comments: [],
            issueComments: [],
            reviewThreads: [],
            minimizedCommentIds: Set(),
            checkRunsStatus: nil,
            branchComparison: nil
        )

        let data = try encoder.encode(snapshot)
        let decoded = try decoder.decode(PRSnapshot.self, from: data)

        XCTAssertNil(decoded.checkRunsStatus)
        XCTAssertNil(decoded.branchComparison)
        XCTAssertTrue(decoded.fileDiffs.isEmpty)
    }
}

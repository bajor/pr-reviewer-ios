import XCTest
@testable import PRReviewer

final class DiffParserTests: XCTestCase {

    // MARK: - parseHunks Tests

    func testParseHunks_emptyPatch_returnsEmptyArray() {
        let result = DiffParser.parseHunks(patch: "")
        XCTAssertTrue(result.isEmpty)
    }

    func testParseHunks_singleHunk_parsesCorrectly() {
        let patch = """
        @@ -1,3 +1,4 @@
         line 1
        +added line
         line 2
         line 3
        """

        let result = DiffParser.parseHunks(patch: patch)

        XCTAssertEqual(result.count, 1)
        let hunk = result[0]
        XCTAssertEqual(hunk.oldStart, 1)
        XCTAssertEqual(hunk.oldCount, 3)
        XCTAssertEqual(hunk.newStart, 1)
        XCTAssertEqual(hunk.newCount, 4)
    }

    func testParseHunks_multipleHunks_parsesAll() {
        let patch = """
        @@ -1,3 +1,3 @@
         line 1
        -old line
        +new line
         line 3
        @@ -10,2 +10,3 @@
         line 10
        +inserted
         line 11
        """

        let result = DiffParser.parseHunks(patch: patch)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].oldStart, 1)
        XCTAssertEqual(result[1].oldStart, 10)
    }

    func testParseHunks_additionLine_hasCorrectType() {
        let patch = """
        @@ -1,1 +1,2 @@
         context
        +added
        """

        let result = DiffParser.parseHunks(patch: patch)
        let lines = result[0].lines

        let additionLine = lines.first { $0.type == .addition }
        XCTAssertNotNil(additionLine)
        XCTAssertEqual(additionLine?.content, "added")
        XCTAssertNil(additionLine?.oldLineNumber)
        XCTAssertNotNil(additionLine?.newLineNumber)
    }

    func testParseHunks_deletionLine_hasCorrectType() {
        let patch = """
        @@ -1,2 +1,1 @@
         context
        -removed
        """

        let result = DiffParser.parseHunks(patch: patch)
        let lines = result[0].lines

        let deletionLine = lines.first { $0.type == .deletion }
        XCTAssertNotNil(deletionLine)
        XCTAssertEqual(deletionLine?.content, "removed")
        XCTAssertNotNil(deletionLine?.oldLineNumber)
        XCTAssertNil(deletionLine?.newLineNumber)
    }

    func testParseHunks_contextLine_hasCorrectType() {
        let patch = """
        @@ -1,1 +1,1 @@
         unchanged
        """

        let result = DiffParser.parseHunks(patch: patch)
        let lines = result[0].lines

        let contextLine = lines.first { $0.type == .context }
        XCTAssertNotNil(contextLine)
        XCTAssertEqual(contextLine?.content, "unchanged")
        XCTAssertNotNil(contextLine?.oldLineNumber)
        XCTAssertNotNil(contextLine?.newLineNumber)
    }

    func testParseHunks_hunkHeader_includedAsFirstLine() {
        let patch = """
        @@ -5,3 +5,3 @@
         line
        """

        let result = DiffParser.parseHunks(patch: patch)
        let firstLine = result[0].lines[0]

        XCTAssertEqual(firstLine.type, .hunkHeader)
        XCTAssertTrue(firstLine.content.hasPrefix("@@"))
    }

    func testParseHunks_lineNumbersIncrement_correctly() {
        let patch = """
        @@ -10,4 +10,4 @@
         line 10
        -deleted at 11
        +added at 11
         line 12
         line 13
        """

        let result = DiffParser.parseHunks(patch: patch)
        let lines = result[0].lines.filter { $0.type != .hunkHeader }

        // First context line
        XCTAssertEqual(lines[0].oldLineNumber, 10)
        XCTAssertEqual(lines[0].newLineNumber, 10)

        // Deletion
        XCTAssertEqual(lines[1].oldLineNumber, 11)
        XCTAssertNil(lines[1].newLineNumber)

        // Addition
        XCTAssertNil(lines[2].oldLineNumber)
        XCTAssertEqual(lines[2].newLineNumber, 11)

        // Context after change
        XCTAssertEqual(lines[3].oldLineNumber, 12)
        XCTAssertEqual(lines[3].newLineNumber, 12)
    }

    // MARK: - parse(file:) Tests

    func testParse_createsFileDiff_withCorrectFilename() {
        let file = PRFile(
            sha: "abc123",
            filename: "test.swift",
            status: .modified,
            additions: 5,
            deletions: 3,
            changes: 8,
            patch: "@@ -1,1 +1,1 @@\n context"
        )

        let result = DiffParser.parse(file: file)

        XCTAssertEqual(result.filename, "test.swift")
        XCTAssertEqual(result.status, .modified)
        XCTAssertEqual(result.additions, 5)
        XCTAssertEqual(result.deletions, 3)
    }

    func testParse_withNilPatch_returnsEmptyHunks() {
        let file = PRFile(
            sha: "abc123",
            filename: "binary.png",
            status: .added,
            additions: 0,
            deletions: 0,
            changes: 0,
            patch: nil
        )

        let result = DiffParser.parse(file: file)

        XCTAssertTrue(result.hunks.isEmpty)
    }

    // MARK: - Hunk Header Parsing Edge Cases

    func testParseHunks_hunkHeaderWithoutCount_defaultsToOne() {
        let patch = """
        @@ -1 +1 @@
         single line
        """

        let result = DiffParser.parseHunks(patch: patch)

        XCTAssertEqual(result[0].oldCount, 1)
        XCTAssertEqual(result[0].newCount, 1)
    }

    func testParseHunks_hunkHeaderWithFunctionContext_parsesCorrectly() {
        let patch = """
        @@ -10,5 +10,6 @@ func someFunction() {
         line
        +added
        """

        let result = DiffParser.parseHunks(patch: patch)

        XCTAssertEqual(result[0].oldStart, 10)
        XCTAssertEqual(result[0].newStart, 10)
    }

    // MARK: - Content Preservation Tests

    func testParseHunks_preservesLeadingWhitespace() {
        let patch = """
        @@ -1,1 +1,1 @@
            indented line
        """

        let result = DiffParser.parseHunks(patch: patch)
        let contextLine = result[0].lines.first { $0.type == .context }

        XCTAssertEqual(contextLine?.content, "   indented line")
    }

    func testParseHunks_preservesEmptyLines() {
        let patch = """
        @@ -1,3 +1,3 @@
         line 1

         line 3
        """

        let result = DiffParser.parseHunks(patch: patch)
        let lines = result[0].lines.filter { $0.type != .hunkHeader }

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[1].content, "")
    }

    func testParseHunks_handlesSpecialCharacters() {
        let patch = """
        @@ -1,1 +1,1 @@
        +let emoji = "🎉"
        """

        let result = DiffParser.parseHunks(patch: patch)
        let additionLine = result[0].lines.first { $0.type == .addition }

        XCTAssertTrue(additionLine?.content.contains("🎉") ?? false)
    }
}

import Foundation

struct DiffParser {
    static func parse(file: PRFile) -> FileDiff {
        let hunks = parseHunks(patch: file.patch ?? "")

        return FileDiff(
            filename: file.filename,
            status: file.status,
            hunks: hunks,
            additions: file.additions,
            deletions: file.deletions
        )
    }

    /// Parse full file content combined with diff info to show entire file with changes highlighted
    static func parseFullFile(file: PRFile, fullContent: String?) -> FileDiff {
        // If no full content, fall back to regular diff parsing
        guard let content = fullContent else {
            return parse(file: file)
        }

        // Parse the patch to get line change information
        let patchInfo = extractPatchInfo(patch: file.patch ?? "")

        // Split full content into lines
        let allLines = content.components(separatedBy: "\n")

        var diffLines: [DiffLine] = []
        var currentLineNum = 1

        for (index, lineContent) in allLines.enumerated() {
            let lineNum = index + 1

            // Check if this line is an addition
            if patchInfo.addedLines.contains(lineNum) {
                diffLines.append(DiffLine(
                    type: .addition,
                    content: lineContent,
                    oldLineNumber: nil,
                    newLineNumber: lineNum
                ))
            }
            // Check if there are deletions before this line
            else {
                // Insert any deletions that should appear before this line
                if let deletions = patchInfo.deletionsBeforeLine[lineNum] {
                    for deletedContent in deletions {
                        diffLines.append(DiffLine(
                            type: .deletion,
                            content: deletedContent,
                            oldLineNumber: currentLineNum,
                            newLineNumber: nil
                        ))
                    }
                }

                // Add the context line
                diffLines.append(DiffLine(
                    type: .context,
                    content: lineContent,
                    oldLineNumber: currentLineNum,
                    newLineNumber: lineNum
                ))
                currentLineNum += 1
            }
        }

        // Add any remaining deletions at the end
        if let deletions = patchInfo.deletionsBeforeLine[allLines.count + 1] {
            for deletedContent in deletions {
                diffLines.append(DiffLine(
                    type: .deletion,
                    content: deletedContent,
                    oldLineNumber: currentLineNum,
                    newLineNumber: nil
                ))
            }
        }

        // Create a single hunk containing all lines
        let hunk = DiffHunk(
            header: "Full file",
            oldStart: 1,
            oldCount: allLines.count,
            newStart: 1,
            newCount: allLines.count,
            lines: diffLines
        )

        return FileDiff(
            filename: file.filename,
            status: file.status,
            hunks: [hunk],
            additions: file.additions,
            deletions: file.deletions
        )
    }

    /// Extract line numbers that are additions/deletions from patch
    private static func extractPatchInfo(patch: String) -> (addedLines: Set<Int>, deletionsBeforeLine: [Int: [String]]) {
        var addedLines = Set<Int>()
        var deletionsBeforeLine: [Int: [String]] = [:]

        guard !patch.isEmpty else {
            return (addedLines, deletionsBeforeLine)
        }

        let lines = patch.components(separatedBy: "\n")
        var newLine = 0
        var pendingDeletions: [String] = []

        for line in lines {
            if line.hasPrefix("@@") {
                // Parse hunk header to get starting line number
                if let parsed = parseHunkHeader(line) {
                    newLine = parsed.newStart

                    // Store any pending deletions
                    if !pendingDeletions.isEmpty {
                        deletionsBeforeLine[newLine] = pendingDeletions
                        pendingDeletions = []
                    }
                }
            } else if line.hasPrefix("+") && !line.hasPrefix("+++") {
                addedLines.insert(newLine)
                newLine += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                let content = String(line.dropFirst())
                pendingDeletions.append(content)
            } else {
                // Context line
                if !pendingDeletions.isEmpty {
                    deletionsBeforeLine[newLine] = pendingDeletions
                    pendingDeletions = []
                }
                newLine += 1
            }
        }

        return (addedLines, deletionsBeforeLine)
    }

    static func parseHunks(patch: String) -> [DiffHunk] {
        guard !patch.isEmpty else { return [] }

        var hunks: [DiffHunk] = []
        let lines = patch.components(separatedBy: "\n")

        var currentHunkHeader: String?
        var currentOldStart = 0
        var currentOldCount = 0
        var currentNewStart = 0
        var currentNewCount = 0
        var currentLines: [DiffLine] = []
        var oldLine = 0
        var newLine = 0

        for line in lines {
            if line.hasPrefix("@@") {
                if let header = currentHunkHeader {
                    hunks.append(DiffHunk(
                        header: header,
                        oldStart: currentOldStart,
                        oldCount: currentOldCount,
                        newStart: currentNewStart,
                        newCount: currentNewCount,
                        lines: currentLines
                    ))
                }

                if let parsed = parseHunkHeader(line) {
                    currentHunkHeader = line
                    currentOldStart = parsed.oldStart
                    currentOldCount = parsed.oldCount
                    currentNewStart = parsed.newStart
                    currentNewCount = parsed.newCount
                    currentLines = [DiffLine(
                        type: .hunkHeader,
                        content: line,
                        oldLineNumber: nil,
                        newLineNumber: nil
                    )]
                    oldLine = parsed.oldStart
                    newLine = parsed.newStart
                }
            } else if currentHunkHeader != nil {
                let diffLine = parseDiffLine(line, oldLine: &oldLine, newLine: &newLine)
                currentLines.append(diffLine)
            }
        }

        if let header = currentHunkHeader {
            hunks.append(DiffHunk(
                header: header,
                oldStart: currentOldStart,
                oldCount: currentOldCount,
                newStart: currentNewStart,
                newCount: currentNewCount,
                lines: currentLines
            ))
        }

        return hunks
    }

    private static func parseHunkHeader(_ line: String) -> (oldStart: Int, oldCount: Int, newStart: Int, newCount: Int)? {
        let pattern = #"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        func captureGroup(_ index: Int) -> Int? {
            guard match.range(at: index).location != NSNotFound,
                  let range = Range(match.range(at: index), in: line) else {
                return nil
            }
            return Int(line[range])
        }

        let oldStart = captureGroup(1) ?? 0
        let oldCount = captureGroup(2) ?? 1
        let newStart = captureGroup(3) ?? 0
        let newCount = captureGroup(4) ?? 1

        return (oldStart, oldCount, newStart, newCount)
    }

    private static func parseDiffLine(_ line: String, oldLine: inout Int, newLine: inout Int) -> DiffLine {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            let content = String(line.dropFirst())
            let diffLine = DiffLine(
                type: .addition,
                content: content,
                oldLineNumber: nil,
                newLineNumber: newLine
            )
            newLine += 1
            return diffLine
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            let content = String(line.dropFirst())
            let diffLine = DiffLine(
                type: .deletion,
                content: content,
                oldLineNumber: oldLine,
                newLineNumber: nil
            )
            oldLine += 1
            return diffLine
        } else {
            let content = line.hasPrefix(" ") ? String(line.dropFirst()) : line
            let diffLine = DiffLine(
                type: .context,
                content: content,
                oldLineNumber: oldLine,
                newLineNumber: newLine
            )
            oldLine += 1
            newLine += 1
            return diffLine
        }
    }
}

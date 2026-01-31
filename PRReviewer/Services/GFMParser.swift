import Foundation

// MARK: - AST Node Types

/// Block-level markdown elements
enum GFMBlock: Equatable {
    case heading(level: Int, content: [GFMInline])
    case paragraph([GFMInline])
    case blockquote([GFMBlock])
    case codeBlock(language: String?, code: String)
    case unorderedList([GFMListItem])
    case orderedList(start: Int, [GFMListItem])
    case table(headers: [[GFMInline]], alignments: [TableAlignment], rows: [[[GFMInline]]])
    case horizontalRule
    case details(summary: [GFMInline], content: [GFMBlock])
}

/// List item that may contain task checkbox
struct GFMListItem: Equatable {
    let isTask: Bool
    let isChecked: Bool
    let content: [GFMBlock]
}

/// Table column alignment
enum TableAlignment: Equatable {
    case left
    case center
    case right
    case none
}

/// Inline markdown elements
indirect enum GFMInline: Equatable {
    case text(String)
    case bold([GFMInline])
    case italic([GFMInline])
    case boldItalic([GFMInline])
    case strikethrough([GFMInline])
    case code(String)
    case link(text: [GFMInline], url: String)
    case image(alt: String, url: String)
    case lineBreak
}

// MARK: - Parser

/// GitHub Flavored Markdown parser
enum GFMParser {

    /// Parse markdown string into AST blocks
    static func parse(_ markdown: String) -> [GFMBlock] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [GFMBlock] = []
        var index = 0

        while index < lines.count {
            let result = parseBlock(lines: lines, startIndex: index)
            if let block = result.block {
                blocks.append(block)
            }
            index = result.nextIndex
        }

        return blocks
    }

    // MARK: - Block Parsing

    private static func parseBlock(lines: [String], startIndex: Int) -> (block: GFMBlock?, nextIndex: Int) {
        guard startIndex < lines.count else {
            return (nil, startIndex + 1)
        }

        let line = lines[startIndex]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip empty lines
        if trimmed.isEmpty {
            return (nil, startIndex + 1)
        }

        // Check for HTML details block
        if trimmed.hasPrefix("<details>") || trimmed.hasPrefix("<details ") {
            return parseDetails(lines: lines, startIndex: startIndex)
        }

        // Check for horizontal rule
        if isHorizontalRule(trimmed) {
            return (.horizontalRule, startIndex + 1)
        }

        // Check for heading
        if let heading = parseHeading(trimmed) {
            return (heading, startIndex + 1)
        }

        // Check for code block
        if trimmed.hasPrefix("```") {
            return parseCodeBlock(lines: lines, startIndex: startIndex)
        }

        // Check for table
        if trimmed.hasPrefix("|") && startIndex + 1 < lines.count {
            let nextLine = lines[startIndex + 1].trimmingCharacters(in: .whitespaces)
            if isTableSeparator(nextLine) {
                return parseTable(lines: lines, startIndex: startIndex)
            }
        }

        // Check for blockquote
        if trimmed.hasPrefix(">") {
            return parseBlockquote(lines: lines, startIndex: startIndex)
        }

        // Check for unordered list
        if isUnorderedListItem(trimmed) {
            return parseUnorderedList(lines: lines, startIndex: startIndex)
        }

        // Check for ordered list
        if isOrderedListItem(trimmed) {
            return parseOrderedList(lines: lines, startIndex: startIndex)
        }

        // Default: paragraph
        return parseParagraph(lines: lines, startIndex: startIndex)
    }

    // MARK: - Heading

    private static func parseHeading(_ line: String) -> GFMBlock? {
        var level = 0
        var idx = line.startIndex

        while idx < line.endIndex && line[idx] == "#" && level < 6 {
            level += 1
            idx = line.index(after: idx)
        }

        guard level > 0 && idx < line.endIndex && line[idx] == " " else {
            return nil
        }

        let content = String(line[line.index(after: idx)...])
        let inlines = parseInline(content)
        return .heading(level: level, content: inlines)
    }

    // MARK: - Horizontal Rule

    private static func isHorizontalRule(_ line: String) -> Bool {
        let stripped = line.filter { !$0.isWhitespace }
        guard stripped.count >= 3 else { return false }

        let firstChar = stripped.first!
        guard firstChar == "-" || firstChar == "*" || firstChar == "_" else { return false }

        return stripped.allSatisfy { $0 == firstChar }
    }

    // MARK: - Code Block

    private static func parseCodeBlock(lines: [String], startIndex: Int) -> (block: GFMBlock?, nextIndex: Int) {
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let language = String(firstLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        let lang = language.isEmpty ? nil : language

        var codeLines: [String] = []
        var index = startIndex + 1

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                index += 1
                break
            }
            codeLines.append(line)
            index += 1
        }

        let code = codeLines.joined(separator: "\n")
        return (.codeBlock(language: lang, code: code), index)
    }

    // MARK: - Blockquote

    private static func parseBlockquote(lines: [String], startIndex: Int) -> (block: GFMBlock?, nextIndex: Int) {
        var quotedLines: [String] = []
        var index = startIndex

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix(">") {
                // Remove > prefix and optional space
                var content = String(trimmed.dropFirst())
                if content.hasPrefix(" ") {
                    content = String(content.dropFirst())
                }
                quotedLines.append(content)
                index += 1
            } else if trimmed.isEmpty && !quotedLines.isEmpty {
                // Empty line might continue blockquote
                index += 1
                if index < lines.count && lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    quotedLines.append("")
                } else {
                    break
                }
            } else {
                break
            }
        }

        let innerMarkdown = quotedLines.joined(separator: "\n")
        let innerBlocks = parse(innerMarkdown)
        return (.blockquote(innerBlocks), index)
    }

    // MARK: - Lists

    private static func isUnorderedListItem(_ line: String) -> Bool {
        let patterns = ["- ", "* ", "+ "]
        return patterns.contains { line.hasPrefix($0) }
    }

    private static func isOrderedListItem(_ line: String) -> Bool {
        guard let dotIndex = line.firstIndex(of: ".") else { return false }
        let prefix = String(line[..<dotIndex])
        guard Int(prefix) != nil else { return false }
        let afterDot = line.index(after: dotIndex)
        return afterDot < line.endIndex && line[afterDot] == " "
    }

    private static func parseUnorderedList(lines: [String], startIndex: Int) -> (block: GFMBlock?, nextIndex: Int) {
        var items: [GFMListItem] = []
        var index = startIndex

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if isUnorderedListItem(trimmed) {
                // Check for task list syntax
                let content = String(trimmed.dropFirst(2))
                let (isTask, isChecked, itemContent) = parseTaskSyntax(content)

                let inlines = parseInline(itemContent)
                let item = GFMListItem(isTask: isTask, isChecked: isChecked, content: [.paragraph(inlines)])
                items.append(item)
                index += 1
            } else if trimmed.isEmpty || !trimmed.hasPrefix(" ") {
                break
            } else {
                index += 1
            }
        }

        return (.unorderedList(items), index)
    }

    private static func parseOrderedList(lines: [String], startIndex: Int) -> (block: GFMBlock?, nextIndex: Int) {
        var items: [GFMListItem] = []
        var index = startIndex
        var startNumber = 1

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if isOrderedListItem(trimmed) {
                if let dotIndex = trimmed.firstIndex(of: ".") {
                    let prefix = String(trimmed[..<dotIndex])
                    if items.isEmpty, let num = Int(prefix) {
                        startNumber = num
                    }
                    let content = String(trimmed[trimmed.index(dotIndex, offsetBy: 2)...])
                    let (isTask, isChecked, itemContent) = parseTaskSyntax(content)

                    let inlines = parseInline(itemContent)
                    let item = GFMListItem(isTask: isTask, isChecked: isChecked, content: [.paragraph(inlines)])
                    items.append(item)
                }
                index += 1
            } else if trimmed.isEmpty {
                break
            } else {
                break
            }
        }

        return (.orderedList(start: startNumber, items), index)
    }

    private static func parseTaskSyntax(_ content: String) -> (isTask: Bool, isChecked: Bool, content: String) {
        if content.hasPrefix("[ ] ") {
            return (true, false, String(content.dropFirst(4)))
        } else if content.hasPrefix("[x] ") || content.hasPrefix("[X] ") {
            return (true, true, String(content.dropFirst(4)))
        }
        return (false, false, content)
    }

    // MARK: - Table

    private static func isTableSeparator(_ line: String) -> Bool {
        let stripped = line.trimmingCharacters(in: .whitespaces)
        guard stripped.hasPrefix("|") else { return false }

        // Check if line contains only |, -, :, and spaces
        let validChars = CharacterSet(charactersIn: "|:-").union(.whitespaces)
        return stripped.unicodeScalars.allSatisfy { validChars.contains($0) }
    }

    private static func parseTable(lines: [String], startIndex: Int) -> (block: GFMBlock?, nextIndex: Int) {
        guard startIndex + 1 < lines.count else {
            return (nil, startIndex + 1)
        }

        // Parse header row
        let headerLine = lines[startIndex]
        let headers = parseTableRow(headerLine)

        // Parse separator and extract alignments
        let separatorLine = lines[startIndex + 1]
        let alignments = parseTableAlignments(separatorLine)

        // Parse data rows
        var rows: [[[GFMInline]]] = []
        var index = startIndex + 2

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("|") {
                let row = parseTableRow(line)
                rows.append(row)
                index += 1
            } else {
                break
            }
        }

        return (.table(headers: headers, alignments: alignments, rows: rows), index)
    }

    private static func parseTableRow(_ line: String) -> [[GFMInline]] {
        var cells: [[GFMInline]] = []
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Split by | but handle escaped pipes
        let parts = trimmed.split(separator: "|", omittingEmptySubsequences: false)

        for (index, part) in parts.enumerated() {
            // Skip first and last empty parts from leading/trailing |
            if index == 0 && part.isEmpty { continue }
            if index == parts.count - 1 && part.isEmpty { continue }

            let cellContent = String(part).trimmingCharacters(in: .whitespaces)
            cells.append(parseInline(cellContent))
        }

        return cells
    }

    private static func parseTableAlignments(_ line: String) -> [TableAlignment] {
        var alignments: [TableAlignment] = []
        let parts = line.split(separator: "|", omittingEmptySubsequences: false)

        for (index, part) in parts.enumerated() {
            if index == 0 && part.isEmpty { continue }
            if index == parts.count - 1 && part.isEmpty { continue }

            let cell = String(part).trimmingCharacters(in: .whitespaces)
            let startsWithColon = cell.hasPrefix(":")
            let endsWithColon = cell.hasSuffix(":")

            if startsWithColon && endsWithColon {
                alignments.append(.center)
            } else if endsWithColon {
                alignments.append(.right)
            } else if startsWithColon {
                alignments.append(.left)
            } else {
                alignments.append(.none)
            }
        }

        return alignments
    }

    // MARK: - Details/Summary HTML

    private static func parseDetails(lines: [String], startIndex: Int) -> (block: GFMBlock?, nextIndex: Int) {
        var index = startIndex
        var summaryInlines: [GFMInline] = [.text("Details")]
        var contentLines: [String] = []
        var inDetails = true
        var foundSummary = false

        // Skip <details> line
        index += 1

        while index < lines.count && inDetails {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("<summary>") && trimmed.hasSuffix("</summary>") {
                // Extract summary text
                let summaryText = trimmed
                    .replacingOccurrences(of: "<summary>", with: "")
                    .replacingOccurrences(of: "</summary>", with: "")
                    .trimmingCharacters(in: .whitespaces)
                summaryInlines = parseInline(summaryText)
                foundSummary = true
            } else if trimmed == "</details>" {
                inDetails = false
            } else if foundSummary || !trimmed.hasPrefix("<summary") {
                contentLines.append(line)
            }

            index += 1
        }

        let innerMarkdown = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let innerBlocks = parse(innerMarkdown)

        return (.details(summary: summaryInlines, content: innerBlocks), index)
    }

    // MARK: - Paragraph

    private static func parseParagraph(lines: [String], startIndex: Int) -> (block: GFMBlock?, nextIndex: Int) {
        var paragraphLines: [String] = []
        var index = startIndex

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Stop at block-level elements or empty lines
            if trimmed.isEmpty ||
               trimmed.hasPrefix("#") ||
               trimmed.hasPrefix("```") ||
               trimmed.hasPrefix(">") ||
               trimmed.hasPrefix("<details") ||
               isUnorderedListItem(trimmed) ||
               isOrderedListItem(trimmed) ||
               isHorizontalRule(trimmed) ||
               (trimmed.hasPrefix("|") && index + 1 < lines.count && isTableSeparator(lines[index + 1])) {
                break
            }

            paragraphLines.append(line)
            index += 1
        }

        let text = paragraphLines.joined(separator: "\n")
        let inlines = parseInline(text)

        guard !inlines.isEmpty else {
            return (nil, index)
        }

        return (.paragraph(inlines), index)
    }

    // MARK: - Inline Parsing

    static func parseInline(_ text: String) -> [GFMInline] {
        var result: [GFMInline] = []
        var current = ""
        var index = text.startIndex

        while index < text.endIndex {
            let remaining = String(text[index...])

            // Check for bold+italic (***text*** or ___text___)
            if let match = matchBoldItalic(remaining) {
                if !current.isEmpty {
                    result.append(.text(current))
                    current = ""
                }
                result.append(.boldItalic(parseInline(match.content)))
                index = text.index(index, offsetBy: match.length)
                continue
            }

            // Check for bold (**text** or __text__)
            if let match = matchBold(remaining) {
                if !current.isEmpty {
                    result.append(.text(current))
                    current = ""
                }
                result.append(.bold(parseInline(match.content)))
                index = text.index(index, offsetBy: match.length)
                continue
            }

            // Check for italic (*text* or _text_)
            if let match = matchItalic(remaining) {
                if !current.isEmpty {
                    result.append(.text(current))
                    current = ""
                }
                result.append(.italic(parseInline(match.content)))
                index = text.index(index, offsetBy: match.length)
                continue
            }

            // Check for strikethrough (~~text~~)
            if let match = matchStrikethrough(remaining) {
                if !current.isEmpty {
                    result.append(.text(current))
                    current = ""
                }
                result.append(.strikethrough(parseInline(match.content)))
                index = text.index(index, offsetBy: match.length)
                continue
            }

            // Check for inline code (`code`)
            if let match = matchInlineCode(remaining) {
                if !current.isEmpty {
                    result.append(.text(current))
                    current = ""
                }
                result.append(.code(match.content))
                index = text.index(index, offsetBy: match.length)
                continue
            }

            // Check for image (![alt](url))
            if let match = matchImage(remaining) {
                if !current.isEmpty {
                    result.append(.text(current))
                    current = ""
                }
                result.append(.image(alt: match.alt, url: match.url))
                index = text.index(index, offsetBy: match.length)
                continue
            }

            // Check for link ([text](url))
            if let match = matchLink(remaining) {
                if !current.isEmpty {
                    result.append(.text(current))
                    current = ""
                }
                result.append(.link(text: parseInline(match.text), url: match.url))
                index = text.index(index, offsetBy: match.length)
                continue
            }

            // Check for line break (two spaces + newline or explicit <br>)
            if remaining.hasPrefix("  \n") {
                if !current.isEmpty {
                    result.append(.text(current))
                    current = ""
                }
                result.append(.lineBreak)
                index = text.index(index, offsetBy: 3)
                continue
            }

            if remaining.hasPrefix("<br>") || remaining.hasPrefix("<br/>") || remaining.hasPrefix("<br />") {
                if !current.isEmpty {
                    result.append(.text(current))
                    current = ""
                }
                result.append(.lineBreak)
                let brLength = remaining.hasPrefix("<br>") ? 4 : (remaining.hasPrefix("<br/>") ? 5 : 6)
                index = text.index(index, offsetBy: brLength)
                continue
            }

            // Regular character
            current.append(text[index])
            index = text.index(after: index)
        }

        if !current.isEmpty {
            result.append(.text(current))
        }

        return result
    }

    // MARK: - Inline Matching Helpers

    private struct InlineMatch {
        let content: String
        let length: Int
    }

    private struct LinkMatch {
        let text: String
        let url: String
        let length: Int
    }

    private struct ImageMatch {
        let alt: String
        let url: String
        let length: Int
    }

    private static func matchBoldItalic(_ text: String) -> InlineMatch? {
        // ***text*** or ___text___
        for marker in ["***", "___"] {
            if text.hasPrefix(marker) {
                let rest = String(text.dropFirst(3))
                if let endIndex = rest.range(of: marker)?.lowerBound {
                    let content = String(rest[..<endIndex])
                    if !content.isEmpty {
                        return InlineMatch(content: content, length: 6 + content.count)
                    }
                }
            }
        }
        return nil
    }

    private static func matchBold(_ text: String) -> InlineMatch? {
        // **text** or __text__
        for marker in ["**", "__"] {
            if text.hasPrefix(marker) && !text.hasPrefix(marker + marker.first!.description) {
                let rest = String(text.dropFirst(2))
                if let endIndex = rest.range(of: marker)?.lowerBound {
                    let content = String(rest[..<endIndex])
                    if !content.isEmpty && !content.hasPrefix(" ") && !content.hasSuffix(" ") {
                        return InlineMatch(content: content, length: 4 + content.count)
                    }
                }
            }
        }
        return nil
    }

    private static func matchItalic(_ text: String) -> InlineMatch? {
        // *text* or _text_ (but not ** or __)
        for marker in ["*", "_"] {
            let doubleMarker = marker + marker
            if text.hasPrefix(marker) && !text.hasPrefix(doubleMarker) {
                let rest = String(text.dropFirst(1))
                // Find closing marker that's not part of a double
                var searchIndex = rest.startIndex
                while searchIndex < rest.endIndex {
                    if let found = rest[searchIndex...].firstIndex(of: Character(marker)) {
                        // Check it's not a double marker
                        let nextIndex = rest.index(after: found)
                        if nextIndex >= rest.endIndex || rest[nextIndex] != Character(marker) {
                            let content = String(rest[..<found])
                            if !content.isEmpty && !content.hasPrefix(" ") && !content.hasSuffix(" ") {
                                return InlineMatch(content: content, length: 2 + content.count)
                            }
                        }
                        searchIndex = nextIndex
                    } else {
                        break
                    }
                }
            }
        }
        return nil
    }

    private static func matchStrikethrough(_ text: String) -> InlineMatch? {
        if text.hasPrefix("~~") {
            let rest = String(text.dropFirst(2))
            if let endIndex = rest.range(of: "~~")?.lowerBound {
                let content = String(rest[..<endIndex])
                if !content.isEmpty {
                    return InlineMatch(content: content, length: 4 + content.count)
                }
            }
        }
        return nil
    }

    private static func matchInlineCode(_ text: String) -> InlineMatch? {
        if text.hasPrefix("`") && !text.hasPrefix("```") {
            let rest = String(text.dropFirst(1))
            if let endIndex = rest.firstIndex(of: "`") {
                let content = String(rest[..<endIndex])
                return InlineMatch(content: content, length: 2 + content.count)
            }
        }
        return nil
    }

    private static func matchLink(_ text: String) -> LinkMatch? {
        guard text.hasPrefix("[") else { return nil }

        // Find matching ]
        var depth = 0
        var bracketEnd: String.Index?
        var idx = text.startIndex

        while idx < text.endIndex {
            if text[idx] == "[" {
                depth += 1
            } else if text[idx] == "]" {
                depth -= 1
                if depth == 0 {
                    bracketEnd = idx
                    break
                }
            }
            idx = text.index(after: idx)
        }

        guard let bracketEndIndex = bracketEnd else { return nil }

        let afterBracket = text.index(after: bracketEndIndex)
        guard afterBracket < text.endIndex && text[afterBracket] == "(" else { return nil }

        // Find closing )
        let urlStart = text.index(after: afterBracket)
        guard let parenEnd = text[urlStart...].firstIndex(of: ")") else { return nil }

        let linkText = String(text[text.index(after: text.startIndex)..<bracketEndIndex])
        let url = String(text[urlStart..<parenEnd])
        let totalLength = text.distance(from: text.startIndex, to: text.index(after: parenEnd))

        return LinkMatch(text: linkText, url: url, length: totalLength)
    }

    private static func matchImage(_ text: String) -> ImageMatch? {
        guard text.hasPrefix("![") else { return nil }

        // Find ]
        guard let bracketEnd = text.dropFirst(2).firstIndex(of: "]") else { return nil }

        let afterBracket = text.index(after: bracketEnd)
        guard afterBracket < text.endIndex && text[afterBracket] == "(" else { return nil }

        // Find )
        let urlStart = text.index(after: afterBracket)
        guard let parenEnd = text[urlStart...].firstIndex(of: ")") else { return nil }

        let alt = String(text[text.index(text.startIndex, offsetBy: 2)..<bracketEnd])
        let url = String(text[urlStart..<parenEnd])
        let totalLength = text.distance(from: text.startIndex, to: text.index(after: parenEnd))

        return ImageMatch(alt: alt, url: url, length: totalLength)
    }
}

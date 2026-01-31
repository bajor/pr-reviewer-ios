import SwiftUI

// MARK: - Main GFM View

/// Renders GitHub Flavored Markdown as SwiftUI views
struct GFMView: View {
    let markdown: String
    let fontSize: CGFloat
    let textColor: Color
    let isResolved: Bool

    init(markdown: String, fontSize: CGFloat = 14, textColor: Color = GruvboxColors.fg1, isResolved: Bool = false) {
        self.markdown = markdown
        self.fontSize = fontSize
        self.textColor = textColor
        self.isResolved = isResolved
    }

    var body: some View {
        let blocks = GFMParser.parse(markdown)
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks.indices, id: \.self) { index in
                GFMBlockView(
                    block: blocks[index],
                    fontSize: fontSize,
                    textColor: textColor
                )
            }
        }
        .opacity(isResolved ? 0.7 : 1.0)
    }
}

// MARK: - Block View

struct GFMBlockView: View {
    let block: GFMBlock
    let fontSize: CGFloat
    let textColor: Color

    var body: some View {
        switch block {
        case .heading(let level, let content):
            GFMHeadingView(level: level, content: content, baseFontSize: fontSize, textColor: textColor)

        case .paragraph(let inlines):
            GFMInlineText(inlines: inlines, fontSize: fontSize, textColor: textColor)
                .fixedSize(horizontal: false, vertical: true)

        case .blockquote(let blocks):
            GFMBlockquoteView(blocks: blocks, fontSize: fontSize, textColor: textColor)

        case .codeBlock(let language, let code):
            GFMCodeBlockView(language: language, code: code, fontSize: fontSize)

        case .unorderedList(let items):
            GFMUnorderedListView(items: items, fontSize: fontSize, textColor: textColor)

        case .orderedList(let start, let items):
            GFMOrderedListView(start: start, items: items, fontSize: fontSize, textColor: textColor)

        case .table(let headers, let alignments, let rows):
            GFMTableView(headers: headers, alignments: alignments, rows: rows, fontSize: fontSize, textColor: textColor)

        case .horizontalRule:
            Rectangle()
                .fill(GruvboxColors.bg3)
                .frame(height: 1)
                .padding(.vertical, 8)

        case .details(let summary, let content):
            GFMDetailsView(summary: summary, content: content, fontSize: fontSize, textColor: textColor)
        }
    }
}

// MARK: - Heading View

struct GFMHeadingView: View {
    let level: Int
    let content: [GFMInline]
    let baseFontSize: CGFloat
    let textColor: Color

    private var headingFont: Font {
        let size: CGFloat
        let weight: Font.Weight

        switch level {
        case 1:
            size = baseFontSize * 1.8
            weight = .bold
        case 2:
            size = baseFontSize * 1.5
            weight = .bold
        case 3:
            size = baseFontSize * 1.25
            weight = .semibold
        case 4:
            size = baseFontSize * 1.1
            weight = .semibold
        case 5:
            size = baseFontSize
            weight = .medium
        default:
            size = baseFontSize * 0.9
            weight = .medium
        }

        return .system(size: size, weight: weight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GFMInlineText(inlines: content, fontSize: headingFontSize, textColor: textColor)
                .fontWeight(headingWeight)

            if level <= 2 {
                Rectangle()
                    .fill(GruvboxColors.bg3)
                    .frame(height: 1)
            }
        }
        .padding(.top, level == 1 ? 8 : 4)
    }

    private var headingFontSize: CGFloat {
        switch level {
        case 1: return baseFontSize * 1.8
        case 2: return baseFontSize * 1.5
        case 3: return baseFontSize * 1.25
        case 4: return baseFontSize * 1.1
        case 5: return baseFontSize
        default: return baseFontSize * 0.9
        }
    }

    private var headingWeight: Font.Weight {
        switch level {
        case 1, 2: return .bold
        case 3, 4: return .semibold
        default: return .medium
        }
    }
}

// MARK: - Blockquote View

struct GFMBlockquoteView: View {
    let blocks: [GFMBlock]
    let fontSize: CGFloat
    let textColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(GruvboxColors.fg4)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(blocks.indices, id: \.self) { index in
                    GFMBlockView(
                        block: blocks[index],
                        fontSize: fontSize,
                        textColor: GruvboxColors.fg3
                    )
                }
            }
            .padding(.leading, 12)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Code Block View

struct GFMCodeBlockView: View {
    let language: String?
    let code: String
    let fontSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let lang = language, !lang.isEmpty {
                Text(lang)
                    .font(.system(size: fontSize - 2, design: .monospaced))
                    .foregroundColor(GruvboxColors.fg4)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(GruvboxColors.bg2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(highlightCode(code, language: language))
                    .font(.system(size: fontSize - 1, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(GruvboxColors.bg1)
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(GruvboxColors.bg2, lineWidth: 1)
        )
    }

    private func highlightCode(_ code: String, language: String?) -> AttributedString {
        var result = AttributedString(code)
        result.foregroundColor = GruvboxColors.fg1

        // Simple syntax highlighting based on common patterns
        guard let lang = language?.lowercased() else { return result }

        // Apply different highlighting based on language
        switch lang {
        case "swift", "javascript", "typescript", "js", "ts", "java", "kotlin", "go", "rust", "python", "py", "ruby", "rb":
            highlightGenericCode(&result, code: code)
        default:
            highlightGenericCode(&result, code: code)
        }

        return result
    }

    private func highlightGenericCode(_ result: inout AttributedString, code: String) {
        // Keywords (common across languages)
        let keywords = ["func", "function", "def", "class", "struct", "enum", "interface", "trait",
                       "if", "else", "switch", "case", "default", "for", "while", "do", "break", "continue",
                       "return", "throw", "try", "catch", "finally", "async", "await",
                       "import", "export", "from", "package", "module",
                       "public", "private", "protected", "static", "final", "const", "let", "var",
                       "true", "false", "nil", "null", "undefined", "self", "this",
                       "new", "delete", "typeof", "instanceof", "in", "of",
                       "fn", "impl", "pub", "mut", "ref", "use", "mod", "crate"]

        for keyword in keywords {
            highlightPattern(&result, in: code, pattern: "\\b\(keyword)\\b", color: GruvboxColors.purpleLight)
        }

        // Strings (simple double and single quotes)
        highlightPattern(&result, in: code, pattern: "\"[^\"\\n]*\"", color: GruvboxColors.greenLight)
        highlightPattern(&result, in: code, pattern: "'[^'\\n]*'", color: GruvboxColors.greenLight)

        // Numbers
        highlightPattern(&result, in: code, pattern: "\\b\\d+(\\.\\d+)?\\b", color: GruvboxColors.orangeLight)

        // Comments (// and #)
        highlightPattern(&result, in: code, pattern: "//.*$", color: GruvboxColors.fg4, multiline: true)
        highlightPattern(&result, in: code, pattern: "#.*$", color: GruvboxColors.fg4, multiline: true)
    }

    private func highlightPattern(_ result: inout AttributedString, in code: String, pattern: String, color: Color, multiline: Bool = false) {
        var options: NSRegularExpression.Options = []
        if multiline {
            options.insert(.anchorsMatchLines)
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }

        let nsRange = NSRange(code.startIndex..., in: code)
        let matches = regex.matches(in: code, range: nsRange)

        for match in matches {
            guard let range = Range(match.range, in: code) else { continue }

            // Convert String range to AttributedString range
            let startOffset = code.distance(from: code.startIndex, to: range.lowerBound)
            let endOffset = code.distance(from: code.startIndex, to: range.upperBound)

            let attrStart = result.index(result.startIndex, offsetByCharacters: startOffset)
            let attrEnd = result.index(result.startIndex, offsetByCharacters: endOffset)

            if attrStart < attrEnd {
                result[attrStart..<attrEnd].foregroundColor = color
            }
        }
    }
}

// MARK: - List Views

struct GFMUnorderedListView: View {
    let items: [GFMListItem]
    let fontSize: CGFloat
    let textColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                GFMListItemView(
                    item: items[index],
                    bullet: bulletFor(items[index]),
                    fontSize: fontSize,
                    textColor: textColor
                )
            }
        }
    }

    private func bulletFor(_ item: GFMListItem) -> String {
        if item.isTask {
            return item.isChecked ? "☑" : "☐"
        }
        return "•"
    }
}

struct GFMOrderedListView: View {
    let start: Int
    let items: [GFMListItem]
    let fontSize: CGFloat
    let textColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                GFMListItemView(
                    item: items[index],
                    bullet: "\(start + index).",
                    fontSize: fontSize,
                    textColor: textColor
                )
            }
        }
    }
}

struct GFMListItemView: View {
    let item: GFMListItem
    let bullet: String
    let fontSize: CGFloat
    let textColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(bullet)
                .font(.system(size: fontSize))
                .foregroundColor(item.isTask && item.isChecked ? GruvboxColors.greenLight : GruvboxColors.fg4)
                .frame(width: 20, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(item.content.indices, id: \.self) { index in
                    GFMBlockView(
                        block: item.content[index],
                        fontSize: fontSize,
                        textColor: item.isTask && item.isChecked ? GruvboxColors.fg4 : textColor
                    )
                }
            }
            .strikethrough(item.isTask && item.isChecked, color: GruvboxColors.fg4)
        }
    }
}

// MARK: - Table View

struct GFMTableView: View {
    let headers: [[GFMInline]]
    let alignments: [TableAlignment]
    let rows: [[[GFMInline]]]
    let fontSize: CGFloat
    let textColor: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                // Header row
                GridRow {
                    ForEach(headers.indices, id: \.self) { colIndex in
                        GFMTableCell(
                            content: headers[colIndex],
                            alignment: alignment(for: colIndex),
                            isHeader: true,
                            fontSize: fontSize,
                            textColor: textColor
                        )
                        .background(GruvboxColors.bg2)
                    }
                }

                // Separator row
                GridRow {
                    ForEach(headers.indices, id: \.self) { _ in
                        Rectangle()
                            .fill(GruvboxColors.bg3)
                            .frame(height: 1)
                    }
                }

                // Data rows
                ForEach(rows.indices, id: \.self) { rowIndex in
                    GridRow {
                        ForEach(0..<headers.count, id: \.self) { colIndex in
                            if colIndex < rows[rowIndex].count {
                                GFMTableCell(
                                    content: rows[rowIndex][colIndex],
                                    alignment: alignment(for: colIndex),
                                    isHeader: false,
                                    fontSize: fontSize,
                                    textColor: textColor
                                )
                                .background(rowIndex % 2 == 0 ? GruvboxColors.bg0 : GruvboxColors.bg1)
                            } else {
                                // Empty cell for missing columns
                                GFMTableCell(
                                    content: [],
                                    alignment: alignment(for: colIndex),
                                    isHeader: false,
                                    fontSize: fontSize,
                                    textColor: textColor
                                )
                                .background(rowIndex % 2 == 0 ? GruvboxColors.bg0 : GruvboxColors.bg1)
                            }
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(GruvboxColors.bg3, lineWidth: 1)
            )
            .cornerRadius(4)
        }
    }

    private func alignment(for index: Int) -> TableAlignment {
        guard index < alignments.count else { return .none }
        return alignments[index]
    }
}

struct GFMTableCell: View {
    let content: [GFMInline]
    let alignment: TableAlignment
    let isHeader: Bool
    let fontSize: CGFloat
    let textColor: Color

    var body: some View {
        GFMInlineText(inlines: content, fontSize: fontSize, textColor: textColor, disableInlineBackgrounds: true)
            .fontWeight(isHeader ? .semibold : .regular)
            .frame(maxWidth: .infinity, alignment: swiftUIAlignment)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }

    private var swiftUIAlignment: Alignment {
        switch alignment {
        case .left, .none: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}

// MARK: - Details View (Collapsible)

struct GFMDetailsView: View {
    let summary: [GFMInline]
    let content: [GFMBlock]
    let fontSize: CGFloat
    let textColor: Color

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: fontSize - 2))
                        .foregroundColor(GruvboxColors.fg4)
                        .frame(width: 12)

                    GFMInlineText(inlines: summary, fontSize: fontSize, textColor: GruvboxColors.aquaLight)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(content.indices, id: \.self) { index in
                        GFMBlockView(
                            block: content[index],
                            fontSize: fontSize,
                            textColor: textColor
                        )
                    }
                }
                .padding(.leading, 18)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(GruvboxColors.bg1)
        .cornerRadius(6)
    }
}

// MARK: - Inline Text Rendering

struct GFMInlineText: View {
    let inlines: [GFMInline]
    let fontSize: CGFloat
    let textColor: Color
    var disableInlineBackgrounds: Bool = false

    var body: some View {
        Text(buildAttributedString())
            .textSelection(.enabled)
    }

    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()

        for inline in inlines {
            result.append(renderInline(inline))
        }

        return result
    }

    private func renderInline(_ inline: GFMInline) -> AttributedString {
        switch inline {
        case .text(let str):
            var attr = AttributedString(str)
            attr.foregroundColor = textColor
            attr.font = .system(size: fontSize)
            return attr

        case .bold(let children):
            var attr = AttributedString()
            for child in children {
                attr.append(renderInline(child))
            }
            attr.font = .system(size: fontSize, weight: .bold)
            return attr

        case .italic(let children):
            var attr = AttributedString()
            for child in children {
                attr.append(renderInline(child))
            }
            attr.font = .system(size: fontSize).italic()
            return attr

        case .boldItalic(let children):
            var attr = AttributedString()
            for child in children {
                attr.append(renderInline(child))
            }
            attr.font = .system(size: fontSize, weight: .bold).italic()
            return attr

        case .strikethrough(let children):
            var attr = AttributedString()
            for child in children {
                attr.append(renderInline(child))
            }
            attr.strikethroughStyle = .single
            return attr

        case .code(let code):
            var attr = AttributedString(code)
            attr.font = .system(size: fontSize - 1, design: .monospaced)
            attr.foregroundColor = GruvboxColors.fg1
            if !disableInlineBackgrounds {
                attr.backgroundColor = GruvboxColors.bg2
            }
            return attr

        case .link(let textInlines, let url):
            var attr = AttributedString()
            for child in textInlines {
                attr.append(renderInline(child))
            }
            attr.foregroundColor = GruvboxColors.aquaLight
            attr.underlineStyle = .single
            if let linkURL = URL(string: url) {
                attr.link = linkURL
            }
            return attr

        case .image(let alt, _):
            // Display alt text with image indicator
            var attr = AttributedString("🖼 \(alt)")
            attr.foregroundColor = GruvboxColors.fg3
            attr.font = .system(size: fontSize)
            return attr

        case .lineBreak:
            return AttributedString("\n")
        }
    }
}

// MARK: - Preview

#Preview("GFM Rendering") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            GFMView(markdown: """
            # Heading 1
            ## Heading 2
            ### Heading 3

            This is a paragraph with **bold**, *italic*, and ~~strikethrough~~ text.

            Here's some `inline code` and a [link](https://github.com).

            > This is a blockquote
            > with multiple lines

            ```swift
            func hello() {
                print("Hello, World!")
            }
            ```

            - Item 1
            - Item 2
            - Item 3

            1. First
            2. Second
            3. Third

            - [x] Completed task
            - [ ] Incomplete task

            | Header 1 | Header 2 |
            |----------|----------|
            | Cell 1   | Cell 2   |
            | Cell 3   | Cell 4   |

            ---

            <details>
            <summary>Click to expand</summary>
            Hidden content here!
            </details>
            """, fontSize: 14, textColor: GruvboxColors.fg1)
        }
        .padding()
    }
    .background(GruvboxColors.bg0)
}

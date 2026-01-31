import XCTest
@testable import PRReviewer

final class GFMParserTests: XCTestCase {

    // MARK: - Heading Tests

    func testParse_heading1_parsesCorrectly() {
        let markdown = "# Hello World"
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 1)
        if case .heading(let level, let content) = result[0] {
            XCTAssertEqual(level, 1)
            XCTAssertEqual(content.count, 1)
            if case .text(let text) = content[0] {
                XCTAssertEqual(text, "Hello World")
            } else {
                XCTFail("Expected text content")
            }
        } else {
            XCTFail("Expected heading block")
        }
    }

    func testParse_heading2_parsesCorrectly() {
        let markdown = "## Section Title"
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 1)
        if case .heading(let level, _) = result[0] {
            XCTAssertEqual(level, 2)
        } else {
            XCTFail("Expected heading block")
        }
    }

    func testParse_heading3_parsesCorrectly() {
        let markdown = "### Subsection"
        let result = GFMParser.parse(markdown)

        if case .heading(let level, _) = result[0] {
            XCTAssertEqual(level, 3)
        } else {
            XCTFail("Expected heading block")
        }
    }

    func testParse_heading4_parsesCorrectly() {
        let markdown = "#### Level 4"
        let result = GFMParser.parse(markdown)

        if case .heading(let level, _) = result[0] {
            XCTAssertEqual(level, 4)
        } else {
            XCTFail("Expected heading block")
        }
    }

    func testParse_heading5_parsesCorrectly() {
        let markdown = "##### Level 5"
        let result = GFMParser.parse(markdown)

        if case .heading(let level, _) = result[0] {
            XCTAssertEqual(level, 5)
        } else {
            XCTFail("Expected heading block")
        }
    }

    func testParse_heading6_parsesCorrectly() {
        let markdown = "###### Level 6"
        let result = GFMParser.parse(markdown)

        if case .heading(let level, _) = result[0] {
            XCTAssertEqual(level, 6)
        } else {
            XCTFail("Expected heading block")
        }
    }

    func testParse_headingWithoutSpace_notParsedAsHeading() {
        let markdown = "#NoSpace"
        let result = GFMParser.parse(markdown)

        // Should be paragraph, not heading (no space after #)
        if case .paragraph(_) = result[0] {
            // Expected
        } else {
            XCTFail("Expected paragraph, not heading")
        }
    }

    func testParse_multipleHeadings_parsesAll() {
        let markdown = """
        # First
        ## Second
        ### Third
        """
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 3)
        if case .heading(let level1, _) = result[0] { XCTAssertEqual(level1, 1) }
        if case .heading(let level2, _) = result[1] { XCTAssertEqual(level2, 2) }
        if case .heading(let level3, _) = result[2] { XCTAssertEqual(level3, 3) }
    }

    // MARK: - Paragraph Tests

    func testParse_simpleParagraph_parsesCorrectly() {
        let markdown = "This is a simple paragraph."
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 1)
        if case .paragraph(let inlines) = result[0] {
            XCTAssertEqual(inlines.count, 1)
            if case .text(let text) = inlines[0] {
                XCTAssertEqual(text, "This is a simple paragraph.")
            }
        } else {
            XCTFail("Expected paragraph")
        }
    }

    func testParse_multipleParagraphs_separatedByBlankLine() {
        let markdown = """
        First paragraph.

        Second paragraph.
        """
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { if case .paragraph(_) = $0 { return true } else { return false } })
    }

    func testParse_paragraphWithMultipleLines_joinedTogether() {
        let markdown = """
        Line one
        Line two
        Line three
        """
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 1)
        if case .paragraph(let inlines) = result[0] {
            if case .text(let text) = inlines[0] {
                XCTAssertTrue(text.contains("Line one"))
                XCTAssertTrue(text.contains("Line two"))
                XCTAssertTrue(text.contains("Line three"))
            }
        }
    }

    // MARK: - Code Block Tests

    func testParse_codeBlock_withoutLanguage() {
        let markdown = """
        ```
        let x = 1
        let y = 2
        ```
        """
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 1)
        if case .codeBlock(let language, let code) = result[0] {
            XCTAssertNil(language)
            XCTAssertTrue(code.contains("let x = 1"))
            XCTAssertTrue(code.contains("let y = 2"))
        } else {
            XCTFail("Expected code block")
        }
    }

    func testParse_codeBlock_withLanguage() {
        let markdown = """
        ```swift
        func hello() {
            print("Hello")
        }
        ```
        """
        let result = GFMParser.parse(markdown)

        if case .codeBlock(let language, let code) = result[0] {
            XCTAssertEqual(language, "swift")
            XCTAssertTrue(code.contains("func hello()"))
        } else {
            XCTFail("Expected code block")
        }
    }

    func testParse_codeBlock_withJavaScript() {
        let markdown = """
        ```javascript
        const x = () => {};
        ```
        """
        let result = GFMParser.parse(markdown)

        if case .codeBlock(let language, _) = result[0] {
            XCTAssertEqual(language, "javascript")
        } else {
            XCTFail("Expected code block")
        }
    }

    func testParse_codeBlock_preservesWhitespace() {
        let markdown = """
        ```
            indented
                more indented
        ```
        """
        let result = GFMParser.parse(markdown)

        if case .codeBlock(_, let code) = result[0] {
            XCTAssertTrue(code.contains("    indented"))
            XCTAssertTrue(code.contains("        more indented"))
        } else {
            XCTFail("Expected code block")
        }
    }

    func testParse_codeBlock_preservesEmptyLines() {
        let markdown = """
        ```
        line1

        line3
        ```
        """
        let result = GFMParser.parse(markdown)

        if case .codeBlock(_, let code) = result[0] {
            let lines = code.components(separatedBy: "\n")
            XCTAssertEqual(lines.count, 3)
            XCTAssertEqual(lines[1], "")
        } else {
            XCTFail("Expected code block")
        }
    }

    func testParse_multipleCodeBlocks_parsesAll() {
        let markdown = """
        ```swift
        let a = 1
        ```

        Some text

        ```python
        x = 2
        ```
        """
        let result = GFMParser.parse(markdown)

        let codeBlocks = result.filter { if case .codeBlock(_, _) = $0 { return true } else { return false } }
        XCTAssertEqual(codeBlocks.count, 2)
    }

    // MARK: - Blockquote Tests

    func testParse_simpleBlockquote_parsesCorrectly() {
        let markdown = "> This is a quote"
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 1)
        if case .blockquote(let blocks) = result[0] {
            XCTAssertEqual(blocks.count, 1)
            if case .paragraph(let inlines) = blocks[0] {
                if case .text(let text) = inlines[0] {
                    XCTAssertEqual(text, "This is a quote")
                }
            }
        } else {
            XCTFail("Expected blockquote")
        }
    }

    func testParse_multilineBlockquote_parsesCorrectly() {
        let markdown = """
        > Line one
        > Line two
        > Line three
        """
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 1)
        if case .blockquote(let blocks) = result[0] {
            XCTAssertGreaterThanOrEqual(blocks.count, 1)
        } else {
            XCTFail("Expected blockquote")
        }
    }

    func testParse_blockquoteWithoutSpaceAfterMarker_stillParses() {
        let markdown = ">Quote without space"
        let result = GFMParser.parse(markdown)

        if case .blockquote(_) = result[0] {
            // Expected
        } else {
            XCTFail("Expected blockquote")
        }
    }

    // MARK: - Unordered List Tests

    func testParse_unorderedList_withDash() {
        let markdown = """
        - Item 1
        - Item 2
        - Item 3
        """
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 1)
        if case .unorderedList(let items) = result[0] {
            XCTAssertEqual(items.count, 3)
            XCTAssertFalse(items[0].isTask)
            XCTAssertFalse(items[1].isTask)
            XCTAssertFalse(items[2].isTask)
        } else {
            XCTFail("Expected unordered list")
        }
    }

    func testParse_unorderedList_withAsterisk() {
        let markdown = """
        * Item A
        * Item B
        """
        let result = GFMParser.parse(markdown)

        if case .unorderedList(let items) = result[0] {
            XCTAssertEqual(items.count, 2)
        } else {
            XCTFail("Expected unordered list")
        }
    }

    func testParse_unorderedList_withPlus() {
        let markdown = """
        + First
        + Second
        """
        let result = GFMParser.parse(markdown)

        if case .unorderedList(let items) = result[0] {
            XCTAssertEqual(items.count, 2)
        } else {
            XCTFail("Expected unordered list")
        }
    }

    // MARK: - Ordered List Tests

    func testParse_orderedList_parsesCorrectly() {
        let markdown = """
        1. First item
        2. Second item
        3. Third item
        """
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 1)
        if case .orderedList(let start, let items) = result[0] {
            XCTAssertEqual(start, 1)
            XCTAssertEqual(items.count, 3)
        } else {
            XCTFail("Expected ordered list")
        }
    }

    func testParse_orderedList_startingAtDifferentNumber() {
        let markdown = """
        5. Fifth
        6. Sixth
        7. Seventh
        """
        let result = GFMParser.parse(markdown)

        if case .orderedList(let start, let items) = result[0] {
            XCTAssertEqual(start, 5)
            XCTAssertEqual(items.count, 3)
        } else {
            XCTFail("Expected ordered list")
        }
    }

    // MARK: - Task List Tests

    func testParse_taskList_unchecked() {
        let markdown = "- [ ] Unchecked task"
        let result = GFMParser.parse(markdown)

        if case .unorderedList(let items) = result[0] {
            XCTAssertEqual(items.count, 1)
            XCTAssertTrue(items[0].isTask)
            XCTAssertFalse(items[0].isChecked)
        } else {
            XCTFail("Expected unordered list with task")
        }
    }

    func testParse_taskList_checked() {
        let markdown = "- [x] Checked task"
        let result = GFMParser.parse(markdown)

        if case .unorderedList(let items) = result[0] {
            XCTAssertEqual(items.count, 1)
            XCTAssertTrue(items[0].isTask)
            XCTAssertTrue(items[0].isChecked)
        } else {
            XCTFail("Expected unordered list with task")
        }
    }

    func testParse_taskList_checkedUppercase() {
        let markdown = "- [X] Checked with uppercase"
        let result = GFMParser.parse(markdown)

        if case .unorderedList(let items) = result[0] {
            XCTAssertTrue(items[0].isTask)
            XCTAssertTrue(items[0].isChecked)
        } else {
            XCTFail("Expected unordered list with task")
        }
    }

    func testParse_taskList_mixedItems() {
        let markdown = """
        - [x] Done
        - [ ] Not done
        - Regular item
        - [x] Also done
        """
        let result = GFMParser.parse(markdown)

        if case .unorderedList(let items) = result[0] {
            XCTAssertEqual(items.count, 4)
            XCTAssertTrue(items[0].isTask && items[0].isChecked)
            XCTAssertTrue(items[1].isTask && !items[1].isChecked)
            XCTAssertFalse(items[2].isTask)
            XCTAssertTrue(items[3].isTask && items[3].isChecked)
        } else {
            XCTFail("Expected unordered list")
        }
    }

    // MARK: - Table Tests

    func testParse_simpleTable_parsesCorrectly() {
        let markdown = """
        | Header 1 | Header 2 |
        |----------|----------|
        | Cell 1   | Cell 2   |
        """
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 1)
        if case .table(let headers, _, let rows) = result[0] {
            XCTAssertEqual(headers.count, 2)
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].count, 2)
        } else {
            XCTFail("Expected table")
        }
    }

    func testParse_tableWithMultipleRows() {
        let markdown = """
        | Name | Age |
        |------|-----|
        | Alice | 30 |
        | Bob | 25 |
        | Carol | 35 |
        """
        let result = GFMParser.parse(markdown)

        if case .table(_, _, let rows) = result[0] {
            XCTAssertEqual(rows.count, 3)
        } else {
            XCTFail("Expected table")
        }
    }

    func testParse_tableWithLeftAlignment() {
        let markdown = """
        | Left |
        |:-----|
        | data |
        """
        let result = GFMParser.parse(markdown)

        if case .table(_, let alignments, _) = result[0] {
            XCTAssertEqual(alignments[0], .left)
        } else {
            XCTFail("Expected table")
        }
    }

    func testParse_tableWithRightAlignment() {
        let markdown = """
        | Right |
        |------:|
        | data |
        """
        let result = GFMParser.parse(markdown)

        if case .table(_, let alignments, _) = result[0] {
            XCTAssertEqual(alignments[0], .right)
        } else {
            XCTFail("Expected table")
        }
    }

    func testParse_tableWithCenterAlignment() {
        let markdown = """
        | Center |
        |:------:|
        | data |
        """
        let result = GFMParser.parse(markdown)

        if case .table(_, let alignments, _) = result[0] {
            XCTAssertEqual(alignments[0], .center)
        } else {
            XCTFail("Expected table")
        }
    }

    func testParse_tableWithMixedAlignments() {
        let markdown = """
        | Left | Center | Right |
        |:-----|:------:|------:|
        | L    | C      | R     |
        """
        let result = GFMParser.parse(markdown)

        if case .table(_, let alignments, _) = result[0] {
            XCTAssertEqual(alignments.count, 3)
            XCTAssertEqual(alignments[0], .left)
            XCTAssertEqual(alignments[1], .center)
            XCTAssertEqual(alignments[2], .right)
        } else {
            XCTFail("Expected table")
        }
    }

    // MARK: - Horizontal Rule Tests

    func testParse_horizontalRule_dashes() {
        let markdown = "---"
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 1)
        if case .horizontalRule = result[0] {
            // Expected
        } else {
            XCTFail("Expected horizontal rule")
        }
    }

    func testParse_horizontalRule_asterisks() {
        let markdown = "***"
        let result = GFMParser.parse(markdown)

        if case .horizontalRule = result[0] {
            // Expected
        } else {
            XCTFail("Expected horizontal rule")
        }
    }

    func testParse_horizontalRule_underscores() {
        let markdown = "___"
        let result = GFMParser.parse(markdown)

        if case .horizontalRule = result[0] {
            // Expected
        } else {
            XCTFail("Expected horizontal rule")
        }
    }

    func testParse_horizontalRule_withSpaces() {
        let markdown = "- - -"
        let result = GFMParser.parse(markdown)

        if case .horizontalRule = result[0] {
            // Expected
        } else {
            XCTFail("Expected horizontal rule")
        }
    }

    func testParse_horizontalRule_longerSequence() {
        let markdown = "----------"
        let result = GFMParser.parse(markdown)

        if case .horizontalRule = result[0] {
            // Expected
        } else {
            XCTFail("Expected horizontal rule")
        }
    }

    // MARK: - Details/Summary Tests

    func testParse_details_simpleCase() {
        let markdown = """
        <details>
        <summary>Click me</summary>
        Hidden content
        </details>
        """
        let result = GFMParser.parse(markdown)

        XCTAssertEqual(result.count, 1)
        if case .details(let summary, let content) = result[0] {
            if case .text(let summaryText) = summary[0] {
                XCTAssertEqual(summaryText, "Click me")
            }
            XCTAssertGreaterThanOrEqual(content.count, 1)
        } else {
            XCTFail("Expected details block")
        }
    }

    func testParse_details_withMultipleParagraphs() {
        let markdown = """
        <details>
        <summary>More info</summary>
        First paragraph.

        Second paragraph.
        </details>
        """
        let result = GFMParser.parse(markdown)

        if case .details(_, let content) = result[0] {
            XCTAssertGreaterThanOrEqual(content.count, 1)
        } else {
            XCTFail("Expected details block")
        }
    }
}

// MARK: - Inline Parsing Tests

final class GFMInlineParserTests: XCTestCase {

    // MARK: - Bold Tests

    func testParseInline_boldWithAsterisks() {
        let result = GFMParser.parseInline("**bold text**")

        XCTAssertEqual(result.count, 1)
        if case .bold(let children) = result[0] {
            if case .text(let text) = children[0] {
                XCTAssertEqual(text, "bold text")
            }
        } else {
            XCTFail("Expected bold")
        }
    }

    func testParseInline_boldWithUnderscores() {
        let result = GFMParser.parseInline("__bold text__")

        if case .bold(let children) = result[0] {
            if case .text(let text) = children[0] {
                XCTAssertEqual(text, "bold text")
            }
        } else {
            XCTFail("Expected bold")
        }
    }

    func testParseInline_boldInMiddleOfText() {
        let result = GFMParser.parseInline("normal **bold** normal")

        XCTAssertEqual(result.count, 3)
        if case .text(let t1) = result[0] { XCTAssertEqual(t1, "normal ") }
        if case .bold(_) = result[1] { /* Expected */ } else { XCTFail("Expected bold") }
        if case .text(let t3) = result[2] { XCTAssertEqual(t3, " normal") }
    }

    // MARK: - Italic Tests

    func testParseInline_italicWithAsterisk() {
        let result = GFMParser.parseInline("*italic text*")

        XCTAssertEqual(result.count, 1)
        if case .italic(let children) = result[0] {
            if case .text(let text) = children[0] {
                XCTAssertEqual(text, "italic text")
            }
        } else {
            XCTFail("Expected italic")
        }
    }

    func testParseInline_italicWithUnderscore() {
        let result = GFMParser.parseInline("_italic text_")

        if case .italic(let children) = result[0] {
            if case .text(let text) = children[0] {
                XCTAssertEqual(text, "italic text")
            }
        } else {
            XCTFail("Expected italic")
        }
    }

    // MARK: - Bold + Italic Tests

    func testParseInline_boldItalicWithAsterisks() {
        let result = GFMParser.parseInline("***bold and italic***")

        if case .boldItalic(let children) = result[0] {
            if case .text(let text) = children[0] {
                XCTAssertEqual(text, "bold and italic")
            }
        } else {
            XCTFail("Expected boldItalic")
        }
    }

    func testParseInline_boldItalicWithUnderscores() {
        let result = GFMParser.parseInline("___bold and italic___")

        if case .boldItalic(let children) = result[0] {
            if case .text(let text) = children[0] {
                XCTAssertEqual(text, "bold and italic")
            }
        } else {
            XCTFail("Expected boldItalic")
        }
    }

    // MARK: - Strikethrough Tests

    func testParseInline_strikethrough() {
        let result = GFMParser.parseInline("~~strikethrough~~")

        XCTAssertEqual(result.count, 1)
        if case .strikethrough(let children) = result[0] {
            if case .text(let text) = children[0] {
                XCTAssertEqual(text, "strikethrough")
            }
        } else {
            XCTFail("Expected strikethrough")
        }
    }

    func testParseInline_strikethroughInSentence() {
        let result = GFMParser.parseInline("This is ~~not~~ correct")

        XCTAssertEqual(result.count, 3)
        if case .strikethrough(let children) = result[1] {
            if case .text(let text) = children[0] {
                XCTAssertEqual(text, "not")
            }
        } else {
            XCTFail("Expected strikethrough")
        }
    }

    // MARK: - Inline Code Tests

    func testParseInline_inlineCode() {
        let result = GFMParser.parseInline("`code here`")

        XCTAssertEqual(result.count, 1)
        if case .code(let code) = result[0] {
            XCTAssertEqual(code, "code here")
        } else {
            XCTFail("Expected code")
        }
    }

    func testParseInline_inlineCodeWithSpecialChars() {
        let result = GFMParser.parseInline("`let x = 1 + 2`")

        if case .code(let code) = result[0] {
            XCTAssertEqual(code, "let x = 1 + 2")
        } else {
            XCTFail("Expected code")
        }
    }

    func testParseInline_inlineCodeInSentence() {
        let result = GFMParser.parseInline("Use `print()` to debug")

        XCTAssertEqual(result.count, 3)
        if case .text(let t1) = result[0] { XCTAssertEqual(t1, "Use ") }
        if case .code(let c) = result[1] { XCTAssertEqual(c, "print()") }
        if case .text(let t2) = result[2] { XCTAssertEqual(t2, " to debug") }
    }

    // MARK: - Link Tests

    func testParseInline_link() {
        let result = GFMParser.parseInline("[GitHub](https://github.com)")

        XCTAssertEqual(result.count, 1)
        if case .link(let textInlines, let url) = result[0] {
            XCTAssertEqual(url, "https://github.com")
            if case .text(let text) = textInlines[0] {
                XCTAssertEqual(text, "GitHub")
            }
        } else {
            XCTFail("Expected link")
        }
    }

    func testParseInline_linkWithFormattedText() {
        let result = GFMParser.parseInline("[**Bold Link**](https://example.com)")

        if case .link(let textInlines, let url) = result[0] {
            XCTAssertEqual(url, "https://example.com")
            if case .bold(_) = textInlines[0] {
                // Expected bold inside link
            } else {
                XCTFail("Expected bold inside link")
            }
        } else {
            XCTFail("Expected link")
        }
    }

    func testParseInline_linkInSentence() {
        let result = GFMParser.parseInline("Visit [our site](https://example.com) for more")

        XCTAssertEqual(result.count, 3)
        if case .link(_, let url) = result[1] {
            XCTAssertEqual(url, "https://example.com")
        } else {
            XCTFail("Expected link")
        }
    }

    // MARK: - Image Tests

    func testParseInline_image() {
        let result = GFMParser.parseInline("![Alt text](https://example.com/image.png)")

        XCTAssertEqual(result.count, 1)
        if case .image(let alt, let url) = result[0] {
            XCTAssertEqual(alt, "Alt text")
            XCTAssertEqual(url, "https://example.com/image.png")
        } else {
            XCTFail("Expected image")
        }
    }

    func testParseInline_imageWithEmptyAlt() {
        let result = GFMParser.parseInline("![](https://example.com/image.png)")

        if case .image(let alt, let url) = result[0] {
            XCTAssertEqual(alt, "")
            XCTAssertEqual(url, "https://example.com/image.png")
        } else {
            XCTFail("Expected image")
        }
    }

    // MARK: - Line Break Tests

    func testParseInline_lineBreakWithTwoSpaces() {
        let result = GFMParser.parseInline("Line one  \nLine two")

        let lineBreaks = result.filter { if case .lineBreak = $0 { return true } else { return false } }
        XCTAssertEqual(lineBreaks.count, 1)
    }

    func testParseInline_lineBreakWithBrTag() {
        let result = GFMParser.parseInline("Line one<br>Line two")

        let lineBreaks = result.filter { if case .lineBreak = $0 { return true } else { return false } }
        XCTAssertEqual(lineBreaks.count, 1)
    }

    func testParseInline_lineBreakWithBrTagSelfClosing() {
        let result = GFMParser.parseInline("Line one<br/>Line two")

        let lineBreaks = result.filter { if case .lineBreak = $0 { return true } else { return false } }
        XCTAssertEqual(lineBreaks.count, 1)
    }

    // MARK: - Mixed Formatting Tests

    func testParseInline_boldInsideItalic() {
        // Note: This tests that we can have bold markers inside italic content
        let result = GFMParser.parseInline("*italic with **bold** inside*")

        if case .italic(let children) = result[0] {
            XCTAssertGreaterThan(children.count, 0)
        } else {
            XCTFail("Expected italic")
        }
    }

    func testParseInline_multipleFormattingTypes() {
        let result = GFMParser.parseInline("**bold** and *italic* and `code`")

        XCTAssertEqual(result.count, 5)
        if case .bold(_) = result[0] { /* Expected */ } else { XCTFail("Expected bold") }
        if case .italic(_) = result[2] { /* Expected */ } else { XCTFail("Expected italic") }
        if case .code(_) = result[4] { /* Expected */ } else { XCTFail("Expected code") }
    }

    func testParseInline_plainText() {
        let result = GFMParser.parseInline("Just plain text here")

        XCTAssertEqual(result.count, 1)
        if case .text(let text) = result[0] {
            XCTAssertEqual(text, "Just plain text here")
        } else {
            XCTFail("Expected text")
        }
    }

    func testParseInline_emptyString() {
        let result = GFMParser.parseInline("")
        XCTAssertTrue(result.isEmpty)
    }
}

// MARK: - Edge Cases and Integration Tests

final class GFMParserEdgeCaseTests: XCTestCase {

    // MARK: - Empty and Whitespace

    func testParse_emptyString_returnsEmpty() {
        let result = GFMParser.parse("")
        XCTAssertTrue(result.isEmpty)
    }

    func testParse_onlyWhitespace_returnsEmpty() {
        let result = GFMParser.parse("   \n\n   ")
        XCTAssertTrue(result.isEmpty)
    }

    func testParse_onlyNewlines_returnsEmpty() {
        let result = GFMParser.parse("\n\n\n")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Special Characters

    func testParse_containsEmoji() {
        let markdown = "Hello 🎉 World"
        let result = GFMParser.parse(markdown)

        if case .paragraph(let inlines) = result[0] {
            if case .text(let text) = inlines[0] {
                XCTAssertTrue(text.contains("🎉"))
            }
        }
    }

    func testParse_containsUnicode() {
        let markdown = "日本語テキスト"
        let result = GFMParser.parse(markdown)

        if case .paragraph(let inlines) = result[0] {
            if case .text(let text) = inlines[0] {
                XCTAssertEqual(text, "日本語テキスト")
            }
        }
    }

    func testParse_containsHtmlEntities() {
        let markdown = "&lt;div&gt;"
        let result = GFMParser.parse(markdown)

        // Should preserve HTML entities as-is (not decode them)
        if case .paragraph(let inlines) = result[0] {
            if case .text(let text) = inlines[0] {
                XCTAssertEqual(text, "&lt;div&gt;")
            }
        }
    }

    // MARK: - Unclosed Formatting

    func testParseInline_unclosedBold_treatedAsText() {
        let result = GFMParser.parseInline("**unclosed bold")

        // Should not crash and should preserve the text
        XCTAssertFalse(result.isEmpty)
    }

    func testParseInline_unclosedItalic_treatedAsText() {
        let result = GFMParser.parseInline("*unclosed italic")
        XCTAssertFalse(result.isEmpty)
    }

    func testParseInline_unclosedCode_treatedAsText() {
        let result = GFMParser.parseInline("`unclosed code")
        XCTAssertFalse(result.isEmpty)
    }

    func testParseInline_unclosedStrikethrough_treatedAsText() {
        let result = GFMParser.parseInline("~~unclosed")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Unclosed Block Elements

    func testParse_unclosedCodeBlock_handlesGracefully() {
        let markdown = """
        ```swift
        let x = 1
        // No closing backticks
        """
        let result = GFMParser.parse(markdown)

        // Should not crash and should capture content
        XCTAssertFalse(result.isEmpty)
    }

    func testParse_unclosedDetails_handlesGracefully() {
        let markdown = """
        <details>
        <summary>Title</summary>
        Content without closing tag
        """
        let result = GFMParser.parse(markdown)
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Nested Structures

    func testParse_nestedBlockquotes() {
        let markdown = """
        > Level 1
        > > Level 2
        """
        let result = GFMParser.parse(markdown)

        // Should handle nested blockquotes
        XCTAssertFalse(result.isEmpty)
    }

    func testParse_codeBlockInsideBlockquote() {
        let markdown = """
        > ```swift
        > let x = 1
        > ```
        """
        let result = GFMParser.parse(markdown)
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Real-World GitHub PR Content

    func testParse_typicalPRDescription() {
        let markdown = """
        ## Summary

        This PR adds a new feature for **user authentication**.

        ### Changes

        - Added login endpoint
        - Added logout endpoint
        - Updated user model

        ### Testing

        - [x] Unit tests pass
        - [x] Integration tests pass
        - [ ] Manual testing

        ```swift
        func authenticate(user: String, password: String) -> Bool {
            // Implementation
            return true
        }
        ```

        For more details, see [the docs](https://example.com/docs).
        """

        let result = GFMParser.parse(markdown)

        // Should have multiple blocks
        XCTAssertGreaterThan(result.count, 5)

        // Should have headings
        let headings = result.filter { if case .heading(_, _) = $0 { return true } else { return false } }
        XCTAssertEqual(headings.count, 3)

        // Should have lists
        let lists = result.filter {
            if case .unorderedList(_) = $0 { return true }
            else { return false }
        }
        XCTAssertGreaterThanOrEqual(lists.count, 2)

        // Should have code block
        let codeBlocks = result.filter { if case .codeBlock(_, _) = $0 { return true } else { return false } }
        XCTAssertEqual(codeBlocks.count, 1)
    }

    func testParse_typicalCodeReviewComment() {
        let markdown = """
        This looks good, but consider using `guard` here:

        ```swift
        guard let user = user else { return }
        ```

        Also, see [this article](https://swift.org/documentation/) for best practices.
        """

        let result = GFMParser.parse(markdown)

        XCTAssertGreaterThan(result.count, 1)

        // Should have code block
        let codeBlocks = result.filter { if case .codeBlock(_, _) = $0 { return true } else { return false } }
        XCTAssertEqual(codeBlocks.count, 1)
    }

    func testParse_changelogStyle() {
        let markdown = """
        ## [1.2.0] - 2024-01-15

        ### Added
        - New login screen
        - Dark mode support

        ### Changed
        - Improved performance

        ### Fixed
        - Memory leak in image loader
        - Crash on startup (#123)
        """

        let result = GFMParser.parse(markdown)

        // Should have heading with version
        let headings = result.filter { if case .heading(_, _) = $0 { return true } else { return false } }
        XCTAssertGreaterThanOrEqual(headings.count, 4)

        // Should have lists
        let lists = result.filter { if case .unorderedList(_) = $0 { return true } else { return false } }
        XCTAssertEqual(lists.count, 3)
    }

    // MARK: - Performance Edge Cases

    func testParse_longDocument_doesNotCrash() {
        var markdown = ""
        for i in 1...100 {
            markdown += "## Section \(i)\n\nParagraph content here with **bold** and *italic* text.\n\n"
        }

        let result = GFMParser.parse(markdown)

        XCTAssertGreaterThan(result.count, 100)
    }

    func testParse_manyInlineElements_doesNotCrash() {
        let markdown = Array(repeating: "**bold** *italic* `code` ~~strike~~", count: 50).joined(separator: " ")

        let result = GFMParser.parse(markdown)

        XCTAssertFalse(result.isEmpty)
    }

    func testParse_deeplyNestedStructure_handlesGracefully() {
        let markdown = """
        > > > > > Deeply nested quote
        """

        let result = GFMParser.parse(markdown)
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Table Edge Cases

    func testParse_tableWithEmptyCells() {
        let markdown = """
        | A | B | C |
        |---|---|---|
        |   | x |   |
        | y |   | z |
        """

        let result = GFMParser.parse(markdown)

        if case .table(_, _, let rows) = result[0] {
            XCTAssertEqual(rows.count, 2)
        } else {
            XCTFail("Expected table")
        }
    }

    func testParse_tableWithFormattedContent() {
        let markdown = """
        | Feature | Status |
        |---------|--------|
        | **Bold** | *Done* |
        | `Code` | ~~Removed~~ |
        """

        let result = GFMParser.parse(markdown)

        if case .table(_, _, let rows) = result[0] {
            XCTAssertEqual(rows.count, 2)
        } else {
            XCTFail("Expected table")
        }
    }

    // MARK: - Mixed Content

    func testParse_mixedBlockTypes() {
        let markdown = """
        # Title

        Paragraph text.

        - List item 1
        - List item 2

        > Quote

        ---

        ```
        code
        ```

        | A | B |
        |---|---|
        | 1 | 2 |
        """

        let result = GFMParser.parse(markdown)

        // Should have: heading, paragraph, list, blockquote, hr, code block, table
        XCTAssertGreaterThanOrEqual(result.count, 6)

        // Verify each type exists
        var hasHeading = false
        var hasParagraph = false
        var hasList = false
        var hasBlockquote = false
        var hasHR = false
        var hasCodeBlock = false
        var hasTable = false

        for block in result {
            switch block {
            case .heading(_, _): hasHeading = true
            case .paragraph(_): hasParagraph = true
            case .unorderedList(_), .orderedList(_, _): hasList = true
            case .blockquote(_): hasBlockquote = true
            case .horizontalRule: hasHR = true
            case .codeBlock(_, _): hasCodeBlock = true
            case .table(_, _, _): hasTable = true
            case .details(_, _): break
            }
        }

        XCTAssertTrue(hasHeading, "Should have heading")
        XCTAssertTrue(hasParagraph, "Should have paragraph")
        XCTAssertTrue(hasList, "Should have list")
        XCTAssertTrue(hasBlockquote, "Should have blockquote")
        XCTAssertTrue(hasHR, "Should have horizontal rule")
        XCTAssertTrue(hasCodeBlock, "Should have code block")
        XCTAssertTrue(hasTable, "Should have table")
    }
}

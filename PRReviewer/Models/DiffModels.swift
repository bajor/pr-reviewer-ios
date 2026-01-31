import Foundation
import SwiftUI

enum DiffLineType: Equatable, Hashable, Sendable {
    case addition
    case deletion
    case context
    case hunkHeader
}

struct DiffLine: Identifiable, Equatable, Sendable {
    let id = UUID()
    let type: DiffLineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?

    var backgroundColor: Color {
        switch type {
        case .addition: return Color.green.opacity(0.25)
        case .deletion: return Color.red.opacity(0.25)
        case .context: return Color.clear
        case .hunkHeader: return Color.blue.opacity(0.1)
        }
    }

    var lineNumberDisplay: String {
        let old = oldLineNumber.map { String($0) } ?? ""
        let new = newLineNumber.map { String($0) } ?? ""
        return "\(old.padding(toLength: 4, withPad: " ", startingAt: 0))\(new.padding(toLength: 4, withPad: " ", startingAt: 0))"
    }
}

struct DiffHunk: Identifiable, Equatable, Sendable {
    let id = UUID()
    let header: String
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let lines: [DiffLine]
}

struct FileDiff: Identifiable, Equatable, Sendable {
    let id = UUID()
    let filename: String
    let status: FileStatus
    let hunks: [DiffHunk]
    let additions: Int
    let deletions: Int
}

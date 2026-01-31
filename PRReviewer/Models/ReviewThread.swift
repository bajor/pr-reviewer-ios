import Foundation

/// Represents a GitHub PR review thread (a conversation on a specific code location)
/// Used for resolving/unresolving threads via GraphQL API
struct ReviewThread: Identifiable, Sendable {
    let id: String  // GraphQL ID (e.g., "PRRT_...")
    let isResolved: Bool
    let viewerCanResolve: Bool
    let viewerCanUnresolve: Bool
    let commentIds: [Int]  // Database IDs of comments in this thread (for matching)

    /// Check if a comment belongs to this thread
    func containsComment(id commentId: Int) -> Bool {
        commentIds.contains(commentId)
    }
}

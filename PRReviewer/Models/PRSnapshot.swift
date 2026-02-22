import Foundation

/// Bundles all data needed to display a PR detail view.
/// Persisted to disk for instant app launch.
struct PRSnapshot: Codable {
    let fileDiffs: [FileDiff]
    let comments: [PRComment]
    let issueComments: [IssueComment]
    let reviewThreads: [ReviewThread]
    let minimizedCommentIds: Set<Int>
    let checkRunsStatus: CheckRunsStatus?
    let branchComparison: BranchComparison?
}

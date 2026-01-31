import Foundation
import Combine

@MainActor
class RefreshManager: ObservableObject {
    static let shared = RefreshManager()

    private var timer: Timer?
    private let interval: TimeInterval = 300  // 5 minutes
    private var refreshAction: (() async -> Void)?

    @Published var lastRefresh: Date?
    @Published var isRefreshing = false

    private init() {}

    func startAutoRefresh(action: @escaping () async -> Void) {
        self.refreshAction = action

        Task {
            await performRefresh()
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performRefresh()
            }
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
        refreshAction = nil
    }

    func triggerManualRefresh() async {
        await performRefresh()
    }

    private func performRefresh() async {
        guard !isRefreshing, let action = refreshAction else { return }

        isRefreshing = true
        await action()
        lastRefresh = Date()
        isRefreshing = false
    }
}

@MainActor
class ChangeDetector {
    private let api = GitHubAPI()
    private let settings = SettingsManager.shared
    private let accountManager = AccountManager.shared
    private let notifications = NotificationManager.shared

    // Track last checked updatedAt per PR to avoid unnecessary API calls
    private var lastCheckedUpdatedAt: [Int: Date] = [:]

    func checkForChanges(pullRequests: [PullRequest]) async {
        let currentUsername = settings.username.lowercased()

        for pr in pullRequests {
            // Skip if PR hasn't been updated since last check
            if let lastChecked = lastCheckedUpdatedAt[pr.id], pr.updatedAt <= lastChecked {
                continue
            }

            await checkPRForChanges(pr, currentUsername: currentUsername)
            lastCheckedUpdatedAt[pr.id] = pr.updatedAt
        }

        // Clean up old entries for PRs no longer in the list
        let currentPRIds = Set(pullRequests.map { $0.id })
        lastCheckedUpdatedAt = lastCheckedUpdatedAt.filter { currentPRIds.contains($0.key) }
    }

    private func checkPRForChanges(_ pr: PullRequest, currentUsername: String) async {
        let oldState = PRStateCache.getState(for: pr.id)

        guard let repoFullName = pr.base.repo?.fullName else { return }
        let components = repoFullName.split(separator: "/")
        guard components.count == 2 else { return }
        let owner = String(components[0])
        let repo = String(components[1])

        do {
            let commits = try await api.getPRCommits(owner: owner, repo: repo, number: pr.number)
            let comments = try await api.getPRComments(owner: owner, repo: repo, number: pr.number)

            let lastCommitSHA = commits.last?.sha ?? pr.head.sha
            let commentCount = comments.count

            if let oldState = oldState {
                if lastCommitSHA != oldState.lastCommitSHA {
                    if let lastCommit = commits.last,
                       let author = lastCommit.author,
                       author.login.lowercased() != currentUsername,
                       !accountManager.isUserBlocked(author.login) {
                        notifications.sendNewCommitNotification(
                            prNumber: pr.number,
                            prTitle: pr.title,
                            repoFullName: repoFullName,
                            authorLogin: author.login,
                            commitMessage: lastCommit.commit.message,
                            playSound: settings.soundEnabled
                        )
                    }
                }

                if commentCount > oldState.commentCount {
                    let newComments = comments.filter { comment in
                        comment.createdAt > oldState.lastChecked &&
                        comment.user.login.lowercased() != currentUsername &&
                        !accountManager.isUserBlocked(comment.user.login)
                    }

                    for comment in newComments {
                        notifications.sendNewCommentNotification(
                            prNumber: pr.number,
                            prTitle: pr.title,
                            repoFullName: repoFullName,
                            authorLogin: comment.user.login,
                            commentBody: comment.body,
                            filePath: comment.path,
                            line: comment.line,
                            commentId: comment.id,
                            playSound: settings.soundEnabled
                        )
                    }
                }
            }

            let newState = PRState(
                prId: pr.id,
                prNumber: pr.number,
                repositoryFullName: repoFullName,
                lastCommitSHA: lastCommitSHA,
                commentCount: commentCount
            )
            PRStateCache.setState(newState, for: pr.id)

        } catch {
            print("Error checking PR #\(pr.number) for changes: \(error)")
        }
    }
}

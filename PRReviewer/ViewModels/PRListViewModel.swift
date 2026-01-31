import Foundation
import Combine
import UserNotifications

@MainActor
class PRListViewModel: ObservableObject {
    @Published var pullRequests: [PullRequest] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedPRIndex: Int = 0

    private let accountManager = AccountManager.shared
    private let refreshManager = RefreshManager.shared
    private let changeDetector = ChangeDetector()
    private let cache = PRCacheService.shared

    func startMonitoring() {
        refreshManager.startAutoRefresh { [weak self] in
            await self?.refreshAll()
        }
    }

    func stopMonitoring() {
        refreshManager.stopAutoRefresh()
    }

    func refreshAll() async {
        await refreshAll(forceRefresh: false)
    }

    /// Refresh PR list. If forceRefresh is false, uses cached data if available.
    func refreshAll(forceRefresh: Bool) async {
        guard accountManager.hasValidCredentials else {
            error = "Please add a GitHub account in Settings"
            return
        }

        // Check cache first (unless forcing refresh)
        if !forceRefresh, let cached = await cache.getPRList() {
            self.pullRequests = cached
            // Still run change detection in background (doesn't block UI)
            Task {
                await changeDetector.checkForChanges(pullRequests: cached)
            }
            return
        }

        isLoading = true
        error = nil

        var allPRs: [PullRequest] = []
        var errors: [String] = []

        // Fetch PRs from all active accounts
        for account in accountManager.activeAccounts {
            guard let token = KeychainManager.getToken(for: account.id) else { continue }

            let api = GitHubAPI(token: token)
            do {
                let prs = try await api.searchPRs(username: account.username)
                allPRs.append(contentsOf: prs)
            } catch {
                errors.append("\(account.username): \(error.localizedDescription)")
            }
        }

        // Remove duplicates (same PR might appear for multiple accounts)
        var seenIds = Set<Int>()
        pullRequests = allPRs.filter { pr in
            if seenIds.contains(pr.id) {
                return false
            }
            seenIds.insert(pr.id)
            return true
        }.sorted { $0.updatedAt > $1.updatedAt }

        // Update cache
        await cache.setPRList(pullRequests)

        // Update app badge
        updateAppBadge(count: pullRequests.count)

        // Check for changes and send notifications
        await changeDetector.checkForChanges(pullRequests: pullRequests)

        if !errors.isEmpty && pullRequests.isEmpty {
            self.error = errors.joined(separator: "\n")
        }

        isLoading = false
    }

    /// Force a full refresh, bypassing all caches
    func forceRefreshAll() async {
        await cache.invalidatePRList()
        await cache.invalidateAllPRDetails()
        await refreshAll(forceRefresh: true)
    }

    private func updateAppBadge(count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }

    func selectPR(at index: Int) {
        guard index >= 0 && index < pullRequests.count else { return }
        selectedPRIndex = index
    }

    var selectedPR: PullRequest? {
        guard selectedPRIndex >= 0 && selectedPRIndex < pullRequests.count else { return nil }
        return pullRequests[selectedPRIndex]
    }
}

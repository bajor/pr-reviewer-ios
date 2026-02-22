import Foundation
import Combine

// Navigation position - diff blocks (consecutive additions/deletions) or comments
enum NavigableItem: Equatable, Hashable {
    case diffBlock(fileIndex: Int, hunkIndex: Int, firstLineIndex: Int, type: DiffLineType)
    case commentGroup(fileIndex: Int, hunkIndex: Int, lineIndex: Int)
}

// Card types for horizontal swipe navigation
enum PRCard: Identifiable, Equatable {
    case description
    case reviewThread(ReviewThread, [PRComment])  // Thread with all its comments
    case generalComment(IssueComment)

    var id: String {
        switch self {
        case .description:
            return "description"
        case .reviewThread(let thread, _):
            return "thread-\(thread.id)"
        case .generalComment(let comment):
            return "general-\(comment.id)"
        }
    }

    static func == (lhs: PRCard, rhs: PRCard) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class PRDetailViewModel: ObservableObject {
    @Published var fileDiffs: [FileDiff] = []
    @Published var comments: [PRComment] = []
    @Published var issueComments: [IssueComment] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentItemIndex: Int = 0

    // Review threads from GitHub (for resolve/unresolve via API)
    @Published var reviewThreads: [ReviewThread] = []

    // Minimized (hidden) comment IDs from GitHub
    @Published var minimizedCommentIds: Set<Int> = []

    // Line selection state (for adding comments)
    @Published var selectedLineKey: String? = nil  // "fileIndex-hunkIndex-lineIndex"

    // Comment creation state
    @Published var showAddComment = false
    @Published var addCommentFile: String = ""
    @Published var addCommentLine: Int = 0
    @Published var isSubmittingComment = false

    // General comment state
    @Published var showAddGeneralComment = false
    @Published var isSubmittingGeneralComment = false

    // PR status (checks and branch sync)
    @Published var checkRunsStatus: CheckRunsStatus?
    @Published var branchComparison: BranchComparison?

    // Folded/collapsed comments (in-memory only, not persisted)
    @Published var foldedCommentIds: Set<Int> = []

    // Card-based navigation
    @Published var currentCardIndex: Int = 0

    // Track if details have been loaded (for lazy loading)
    @Published private(set) var isLoaded = false

    // Disappeared files (shown as green banner after background sync)
    @Published var disappearedFiles: [String] = []

    let pullRequest: PullRequest
    private let api = GitHubAPI()
    private let settings = SettingsManager.shared
    private let cache = PRCacheService.shared
    private let diskCache = PRDiskCache.shared

    private var navigableItems: [NavigableItem] = []
    private var isSyncing = false
    private var pendingSnapshot: PRSnapshot?

    init(pullRequest: PullRequest) {
        self.pullRequest = pullRequest
    }

    var owner: String {
        pullRequest.base.repo?.owner.login ?? ""
    }

    var repo: String {
        pullRequest.base.repo?.name ?? ""
    }

    var currentItem: NavigableItem? {
        guard currentItemIndex >= 0 && currentItemIndex < navigableItems.count else { return nil }
        return navigableItems[currentItemIndex]
    }

    /// Refresh review threads and minimized IDs, logging any errors
    private func refreshReviewThreads() async {
        do {
            let (threads, minimizedIds) = try await api.getReviewThreads(owner: owner, repo: repo, number: pullRequest.number)
            self.reviewThreads = threads
            self.minimizedCommentIds = minimizedIds
        } catch {
            // Log but don't fail - threads are supplementary data
            print("Failed to refresh review threads: \(error.localizedDescription)")
        }
    }

    /// Load PR details, checking in-memory cache, then disk cache, then network.
    /// After loading from cache, kicks off a background sync to get fresh data.
    func loadDetails() async {
        guard !isLoaded else { return }

        // L1: in-memory cache
        if let cached = await cache.getPRDetails(for: pullRequest.id) {
            applyPRDetails(cached)
            isLoaded = true
            Task { await syncInBackground() }
            return
        }

        // L2: disk cache (instant, no spinner)
        if let snapshot = await diskCache.loadSnapshot(for: pullRequest.id) {
            applySnapshot(snapshot)
            isLoaded = true
            Task { await syncInBackground() }
            return
        }

        // L3: network (with spinner)
        await loadDetailsFromNetwork()
    }

    /// Force refresh from network, bypassing cache
    func forceRefresh() async {
        await cache.invalidatePRDetails(for: pullRequest.id)
        isLoaded = false
        await loadDetailsFromNetwork()
    }

    private func loadDetailsFromNetwork() async {
        isLoading = true
        error = nil

        do {
            let snapshot = try await fetchFullSnapshot()
            applySnapshot(snapshot)
            await saveSnapshotToCaches(snapshot)
            isLoaded = true
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Background Sync

    /// Fetch fresh data in background without blocking UI.
    /// If user is editing a comment, defers the swap until they finish.
    private func syncInBackground() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let snapshot = try await fetchFullSnapshot()
            await saveSnapshotToCaches(snapshot)

            if isUserEditing {
                pendingSnapshot = snapshot
            } else {
                applySnapshot(snapshot)
            }
        } catch {
            // Silent failure - old data stays displayed
        }
    }

    /// Fetch all PR data into a snapshot without side effects on @Published properties.
    private func fetchFullSnapshot() async throws -> PRSnapshot {
        async let filesTask = api.getPRFiles(owner: owner, repo: repo, number: pullRequest.number)
        async let commentsTask = api.getPRComments(owner: owner, repo: repo, number: pullRequest.number)
        async let issueCommentsTask = api.getIssueComments(owner: owner, repo: repo, number: pullRequest.number)

        let (files, prComments, fetchedIssueComments) = try await (filesTask, commentsTask, issueCommentsTask)

        var diffs: [FileDiff] = []
        for file in files {
            let fullContent = await getFileContentCached(path: file.filename, ref: pullRequest.head.sha)
            diffs.append(DiffParser.parseFullFile(file: file, fullContent: fullContent))
        }

        let filteredComments = filterActiveComments(prComments, against: diffs)

        let (threads, minimizedIds) = (try? await api.getReviewThreads(owner: owner, repo: repo, number: pullRequest.number)) ?? ([], Set())
        let checkRuns = try? await api.getCheckRuns(owner: owner, repo: repo, ref: pullRequest.head.sha)
        let branchComp = try? await api.compareBranches(
            owner: owner, repo: repo,
            base: pullRequest.base.ref, head: pullRequest.head.ref
        )

        return PRSnapshot(
            pullRequest: pullRequest,
            fileDiffs: diffs,
            comments: filteredComments,
            issueComments: fetchedIssueComments,
            reviewThreads: threads,
            minimizedCommentIds: minimizedIds,
            checkRunsStatus: checkRuns,
            branchComparison: branchComp,
            headSHA: pullRequest.head.sha,
            savedAt: Date()
        )
    }

    /// Save snapshot to both in-memory and disk caches.
    private func saveSnapshotToCaches(_ snapshot: PRSnapshot) async {
        let details = PRCacheService.PRDetails(
            fileDiffs: snapshot.fileDiffs,
            comments: snapshot.comments,
            issueComments: snapshot.issueComments,
            reviewThreads: snapshot.reviewThreads,
            minimizedCommentIds: snapshot.minimizedCommentIds,
            checkRunsStatus: snapshot.checkRunsStatus,
            branchComparison: snapshot.branchComparison
        )
        await cache.setPRDetails(details, for: pullRequest.id)
        try? await diskCache.saveSnapshot(snapshot, for: pullRequest.id)
    }

    /// Check if user is currently editing a comment (prevents state swap).
    private var isUserEditing: Bool {
        showAddComment || showAddGeneralComment || isSubmittingComment || isSubmittingGeneralComment
    }

    /// Apply pending snapshot if user is done editing.
    func checkPendingSwap() {
        guard let snapshot = pendingSnapshot, !isUserEditing else { return }
        pendingSnapshot = nil
        applySnapshot(snapshot)
    }

    /// Get file content with caching
    private func getFileContentCached(path: String, ref: String) async -> String? {
        let key = PRCacheService.fileContentKey(owner: owner, repo: repo, path: path, ref: ref)

        // Check cache
        if let cached = await cache.getFileContent(key: key) {
            return cached
        }

        // Fetch from network
        let content = try? await api.getFileContent(owner: owner, repo: repo, path: path, ref: ref)

        // Cache result
        if let content = content {
            await cache.setFileContent(content, key: key)
        }

        return content
    }

    /// Apply cached PR details to view model
    private func applyPRDetails(_ details: PRCacheService.PRDetails) {
        self.fileDiffs = details.fileDiffs
        self.comments = details.comments
        self.issueComments = details.issueComments
        self.reviewThreads = details.reviewThreads
        self.minimizedCommentIds = details.minimizedCommentIds
        self.checkRunsStatus = details.checkRunsStatus
        self.branchComparison = details.branchComparison
        self.navigableItems = buildNavigableItems()
        self.currentItemIndex = 0
    }

    /// Apply a snapshot to view model, detecting disappeared files from background sync.
    private func applySnapshot(_ snapshot: PRSnapshot) {
        if !fileDiffs.isEmpty {
            let oldFilenames = Set(fileDiffs.map(\.filename))
            let newFilenames = Set(snapshot.fileDiffs.map(\.filename))
            let disappeared = oldFilenames.subtracting(newFilenames)
            if !disappeared.isEmpty {
                self.disappearedFiles = disappeared.sorted()
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(5))
                    self.disappearedFiles = []
                }
            }
        }

        self.fileDiffs = snapshot.fileDiffs
        self.comments = snapshot.comments
        self.issueComments = snapshot.issueComments
        self.reviewThreads = snapshot.reviewThreads
        self.minimizedCommentIds = snapshot.minimizedCommentIds
        self.checkRunsStatus = snapshot.checkRunsStatus
        self.branchComparison = snapshot.branchComparison
        self.navigableItems = buildNavigableItems()
        self.currentItemIndex = min(self.currentItemIndex, max(0, navigableItems.count - 1))
    }

    private func filterActiveComments(_ comments: [PRComment], against diffs: [FileDiff]) -> [PRComment] {
        comments.filter { comment in
            guard let path = comment.path, let line = comment.line else {
                return true
            }

            guard let file = diffs.first(where: { $0.filename == path }) else {
                return false
            }

            return file.hunks.contains { hunk in
                hunk.lines.contains { diffLine in
                    diffLine.newLineNumber == line || diffLine.oldLineNumber == line
                }
            }
        }
    }

    // Build list of navigable items: diff blocks (consecutive same-type changes) and comment groups
    private func buildNavigableItems() -> [NavigableItem] {
        var items: [NavigableItem] = []

        for (fileIndex, file) in fileDiffs.enumerated() {
            for (hunkIndex, hunk) in file.hunks.enumerated() {
                var lineIndex = 0
                while lineIndex < hunk.lines.count {
                    let line = hunk.lines[lineIndex]

                    // Skip context lines and hunk headers
                    guard line.type == .addition || line.type == .deletion else {
                        lineIndex += 1
                        continue
                    }

                    // Check if this line has comments - comments are separate nav items
                    if hasComment(for: file.filename, line: line) {
                        items.append(.commentGroup(fileIndex: fileIndex, hunkIndex: hunkIndex, lineIndex: lineIndex))
                        lineIndex += 1
                        continue
                    }

                    // Start of a diff block - find all consecutive lines of same type
                    let blockType = line.type
                    let blockStart = lineIndex

                    // Skip over all consecutive lines of the same type (that don't have comments)
                    while lineIndex < hunk.lines.count {
                        let currentLine = hunk.lines[lineIndex]
                        if currentLine.type != blockType {
                            break
                        }
                        // If this line has a comment, stop the block before it
                        if hasComment(for: file.filename, line: currentLine) && lineIndex > blockStart {
                            break
                        }
                        lineIndex += 1
                    }

                    // Add the diff block (pointing to first line)
                    items.append(.diffBlock(fileIndex: fileIndex, hunkIndex: hunkIndex, firstLineIndex: blockStart, type: blockType))
                }
            }
        }

        return items
    }

    func hasComment(for filename: String, line: DiffLine) -> Bool {
        let lineNumber = line.newLineNumber ?? line.oldLineNumber
        return comments.contains { comment in
            comment.path == filename && comment.line == lineNumber && shouldShowComment(comment)
        }
    }

    func commentsFor(filename: String, line: DiffLine) -> [PRComment] {
        let lineNumber = line.newLineNumber ?? line.oldLineNumber
        return comments.filter { comment in
            comment.path == filename && comment.line == lineNumber && shouldShowComment(comment)
        }
    }

    func navigateToNext() {
        guard currentItemIndex < navigableItems.count - 1 else { return }
        currentItemIndex += 1
    }

    func navigateToPrevious() {
        guard currentItemIndex > 0 else { return }
        currentItemIndex -= 1
    }

    var canNavigateNext: Bool {
        currentItemIndex < navigableItems.count - 1
    }

    var canNavigatePrevious: Bool {
        currentItemIndex > 0
    }

    var navigationStatus: String {
        guard !navigableItems.isEmpty else { return "0/0" }
        return "\(currentItemIndex + 1)/\(navigableItems.count)"
    }

    // MARK: - Card-Based Navigation

    /// Build list of cards for horizontal swiping
    var cards: [PRCard] {
        var result: [PRCard] = [.description]

        // Add unresolved review threads (code comments that can be resolved)
        // Filter: only show threads that are NOT resolved
        let unresolvedThreads = reviewThreads.filter { !$0.isResolved }
        for thread in unresolvedThreads {
            // Collect all visible comments in this thread, sorted by date
            // - Filter out minimized comments
            // - Filter out comments in resolved threads (double-check)
            let threadComments = comments
                .filter { thread.containsComment(id: $0.id) && shouldShowComment($0) }
                .sorted { $0.createdAt < $1.createdAt }

            // Only add card if thread has visible comments
            if !threadComments.isEmpty {
                result.append(.reviewThread(thread, threadComments))
            }
        }

        // Add general/issue comments
        // Note: Hidden comments are filtered out by GitHub API response
        for comment in issueComments {
            result.append(.generalComment(comment))
        }

        return result
    }

    var cardNavigationStatus: String {
        guard !cards.isEmpty else { return "0/0" }
        return "\(currentCardIndex + 1)/\(cards.count)"
    }

    /// Get code context for a comment (the file diff containing this comment)
    func codeContextFor(comment: PRComment) -> (file: FileDiff, hunk: DiffHunk, lineIndex: Int)? {
        guard let path = comment.path, let line = comment.line else { return nil }

        for file in fileDiffs {
            if file.filename == path {
                for hunk in file.hunks {
                    for (lineIndex, diffLine) in hunk.lines.enumerated() {
                        if diffLine.newLineNumber == line || diffLine.oldLineNumber == line {
                            return (file, hunk, lineIndex)
                        }
                    }
                }
            }
        }
        return nil
    }

    // Returns scroll ID for current item (first line of diff block)
    var currentScrollId: String? {
        guard let item = currentItem else { return nil }
        switch item {
        case .diffBlock(let fileIndex, let hunkIndex, let firstLineIndex, _):
            return "line-\(fileIndex)-\(hunkIndex)-\(firstLineIndex)"
        case .commentGroup(let fileIndex, let hunkIndex, let lineIndex):
            return "line-\(fileIndex)-\(hunkIndex)-\(lineIndex)"
        }
    }

    // Check if a line is the first line of the current diff block
    func isCurrentLine(fileIndex: Int, hunkIndex: Int, lineIndex: Int) -> Bool {
        guard let item = currentItem else { return false }
        switch item {
        case .diffBlock(let f, let h, let firstLine, _):
            return f == fileIndex && h == hunkIndex && firstLine == lineIndex
        case .commentGroup(let f, let h, let l):
            return f == fileIndex && h == hunkIndex && l == lineIndex
        }
    }

    // Check if a line's comments are the current navigation target
    func isCurrentCommentGroup(fileIndex: Int, hunkIndex: Int, lineIndex: Int) -> Bool {
        guard let item = currentItem else { return false }
        if case .commentGroup(let f, let h, let l) = item {
            return f == fileIndex && h == hunkIndex && l == lineIndex
        }
        return false
    }

    // MARK: - Comment Actions

    func prepareAddComment(file: String, line: Int) {
        addCommentFile = file
        addCommentLine = line
        showAddComment = true
    }

    func submitComment(_ body: String) async -> Bool {
        guard !body.isEmpty else { return false }

        isSubmittingComment = true

        do {
            try await api.createReviewComment(
                owner: owner,
                repo: repo,
                number: pullRequest.number,
                body: body,
                path: addCommentFile,
                line: addCommentLine,
                commitId: pullRequest.head.sha
            )

            // Reload comments
            let newComments = try await api.getPRComments(owner: owner, repo: repo, number: pullRequest.number)
            self.comments = filterActiveComments(newComments, against: fileDiffs)
            self.navigableItems = buildNavigableItems()

            isSubmittingComment = false
            showAddComment = false
            checkPendingSwap()
            return true
        } catch {
            self.error = error.localizedDescription
            isSubmittingComment = false
            return false
        }
    }

    func replyToComment(_ comment: PRComment, body: String) async -> Bool {
        guard !body.isEmpty else { return false }

        do {
            try await api.replyToComment(
                owner: owner,
                repo: repo,
                number: pullRequest.number,
                commentId: comment.id,
                body: body
            )

            // Reload comments
            let newComments = try await api.getPRComments(owner: owner, repo: repo, number: pullRequest.number)
            self.comments = filterActiveComments(newComments, against: fileDiffs)

            // Refresh review threads so new reply appears in cards
            await refreshReviewThreads()

            self.navigableItems = buildNavigableItems()

            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func submitGeneralComment(_ body: String) async -> Bool {
        guard !body.isEmpty else { return false }

        isSubmittingGeneralComment = true

        do {
            try await api.createIssueComment(
                owner: owner,
                repo: repo,
                number: pullRequest.number,
                body: body
            )

            // Reload issue comments
            let newIssueComments = try await api.getIssueComments(owner: owner, repo: repo, number: pullRequest.number)
            self.issueComments = newIssueComments

            isSubmittingGeneralComment = false
            showAddGeneralComment = false
            checkPendingSwap()
            return true
        } catch {
            self.error = error.localizedDescription
            isSubmittingGeneralComment = false
            return false
        }
    }

    // MARK: - Comment Visibility

    /// Check if a comment should be visible
    /// Hidden if: in a resolved thread, minimized, or locally hidden
    func shouldShowComment(_ comment: PRComment) -> Bool {
        // Check if minimized on GitHub
        if minimizedCommentIds.contains(comment.id) {
            return false
        }

        // Check if in a resolved thread on GitHub
        if let thread = getThreadForComment(comment), thread.isResolved {
            return false
        }

        return true
    }

    /// Get visible comments for a specific file and line
    func visibleCommentsFor(filename: String, line: DiffLine) -> [PRComment] {
        let lineNumber = line.newLineNumber ?? line.oldLineNumber
        return comments.filter { comment in
            comment.path == filename && comment.line == lineNumber && shouldShowComment(comment)
        }
    }

    // MARK: - Comment Folding (In-Memory)

    /// Check if a comment is folded/collapsed
    func isCommentFolded(_ commentId: Int) -> Bool {
        foldedCommentIds.contains(commentId)
    }

    /// Toggle fold state for a comment
    func toggleCommentFolded(_ commentId: Int) {
        if foldedCommentIds.contains(commentId) {
            foldedCommentIds.remove(commentId)
        } else {
            foldedCommentIds.insert(commentId)
        }
    }

    /// Fold a comment
    func foldComment(_ commentId: Int) {
        foldedCommentIds.insert(commentId)
    }

    /// Unfold a comment
    func unfoldComment(_ commentId: Int) {
        foldedCommentIds.remove(commentId)
    }

    // MARK: - Review Thread Management (GitHub API)

    /// Find the review thread that contains this comment
    func getThreadForComment(_ comment: PRComment) -> ReviewThread? {
        reviewThreads.first { $0.containsComment(id: comment.id) }
    }

    /// Check if a thread is resolved on GitHub
    func isThreadResolved(_ comment: PRComment) -> Bool {
        getThreadForComment(comment)?.isResolved ?? false
    }

    /// Check if the current user can resolve a comment's thread
    func canResolveComment(_ comment: PRComment) -> Bool {
        guard let thread = getThreadForComment(comment) else {
            return false  // No thread found - can't resolve
        }
        return thread.viewerCanResolve && !thread.isResolved
    }

    /// Check if the current user can unresolve a comment's thread
    func canUnresolveComment(_ comment: PRComment) -> Bool {
        guard let thread = getThreadForComment(comment) else {
            return false  // No thread found - can't unresolve
        }
        return thread.viewerCanUnresolve && thread.isResolved
    }

    /// Resolve a review thread via GitHub API
    func resolveThread(for comment: PRComment) async -> Bool {
        guard let thread = getThreadForComment(comment) else {
            self.error = "No thread found for this comment"
            return false
        }

        guard thread.viewerCanResolve else {
            self.error = "You don't have permission to resolve this thread"
            return false
        }

        do {
            try await api.resolveReviewThread(threadId: thread.id)

            // Refresh threads and minimized IDs
            await refreshReviewThreads()
            self.navigableItems = buildNavigableItems()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Unresolve a review thread via GitHub API
    func unresolveThread(for comment: PRComment) async -> Bool {
        guard let thread = getThreadForComment(comment) else {
            self.error = "No thread found for this comment"
            return false
        }

        guard thread.viewerCanUnresolve else {
            self.error = "You don't have permission to unresolve this thread"
            return false
        }

        do {
            try await api.unresolveReviewThread(threadId: thread.id)

            // Refresh threads and minimized IDs
            await refreshReviewThreads()
            self.navigableItems = buildNavigableItems()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Minimize (hide) a PR review comment via GitHub API
    func minimizeComment(_ comment: PRComment, reason: MinimizeReason = .resolved) async -> Bool {
        do {
            try await api.minimizeComment(nodeId: comment.nodeId, reason: reason)

            // Immediately add to minimized set for instant UI update
            self.minimizedCommentIds.insert(comment.id)

            // Reload comments and refresh threads
            let newComments = try await api.getPRComments(owner: owner, repo: repo, number: pullRequest.number)
            self.comments = filterActiveComments(newComments, against: fileDiffs)
            await refreshReviewThreads()
            self.navigableItems = buildNavigableItems()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Delete an issue comment via GitHub API
    func deleteIssueComment(_ comment: IssueComment) async -> Bool {
        do {
            try await api.deleteIssueComment(owner: owner, repo: repo, commentId: comment.id)

            // Remove from local list immediately
            self.issueComments.removeAll { $0.id == comment.id }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Deep Link Navigation

    /// Navigate to a specific file and line (from notification deep link)
    func navigateToFileLine(filePath: String, line: Int) {
        // Find the file index
        guard let fileIndex = fileDiffs.firstIndex(where: { $0.filename == filePath }) else {
            return
        }

        let file = fileDiffs[fileIndex]

        // Find the hunk and line that matches
        for (hunkIndex, hunk) in file.hunks.enumerated() {
            for (lineIndex, diffLine) in hunk.lines.enumerated() {
                let lineNumber = diffLine.newLineNumber ?? diffLine.oldLineNumber
                if lineNumber == line {
                    // Find the navigable item that contains this line
                    if let itemIndex = navigableItems.firstIndex(where: { item in
                        switch item {
                        case .diffBlock(let f, let h, let firstLine, _):
                            if f == fileIndex && h == hunkIndex {
                                // Check if line is in this block
                                let blockEnd = findBlockEnd(fileIndex: f, hunkIndex: h, startLine: firstLine)
                                return lineIndex >= firstLine && lineIndex <= blockEnd
                            }
                            return false
                        case .commentGroup(let f, let h, let l):
                            return f == fileIndex && h == hunkIndex && l == lineIndex
                        }
                    }) {
                        currentItemIndex = itemIndex
                        return
                    }
                }
            }
        }
    }

    /// Find the end line index of a diff block
    private func findBlockEnd(fileIndex: Int, hunkIndex: Int, startLine: Int) -> Int {
        guard fileIndex < fileDiffs.count else { return startLine }
        let file = fileDiffs[fileIndex]
        guard hunkIndex < file.hunks.count else { return startLine }
        let hunk = file.hunks[hunkIndex]
        guard startLine < hunk.lines.count else { return startLine }

        let blockType = hunk.lines[startLine].type
        var endLine = startLine

        for i in (startLine + 1)..<hunk.lines.count {
            let line = hunk.lines[i]
            if line.type != blockType {
                break
            }
            if hasComment(for: file.filename, line: line) {
                break
            }
            endLine = i
        }

        return endLine
    }
}

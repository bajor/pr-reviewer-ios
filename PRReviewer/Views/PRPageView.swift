import SwiftUI

struct PRPageView: View {
    @ObservedObject var viewModel: PRListViewModel
    @StateObject private var detailViewModelStore = PRDetailViewModelStore()

    var body: some View {
        TabView(selection: $viewModel.selectedPRIndex) {
            ForEach(Array(viewModel.pullRequests.enumerated()), id: \.element.id) { index, pr in
                PRDetailContainerView(
                    pullRequest: pr,
                    detailViewModel: detailViewModelStore.viewModel(for: pr),
                    isVisible: viewModel.selectedPRIndex == index
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .bottom)
    }
}

/// Stores and reuses PRDetailViewModels to prevent recreation on every swipe
@MainActor
class PRDetailViewModelStore: ObservableObject {
    private var viewModels: [Int: PRDetailViewModel] = [:]

    func viewModel(for pr: PullRequest) -> PRDetailViewModel {
        if let existing = viewModels[pr.id] {
            return existing
        }
        let vm = PRDetailViewModel(pullRequest: pr)
        viewModels[pr.id] = vm
        return vm
    }

    func invalidate(prId: Int) {
        viewModels.removeValue(forKey: prId)
    }

    func invalidateAll() {
        viewModels.removeAll()
    }
}

enum PRViewMode {
    case description
    case code
}

struct PRDetailContainerView: View {
    let pullRequest: PullRequest
    var navigationTarget: NotificationTarget?
    var onBack: (() -> Void)?
    var onNavigationComplete: (() -> Void)?
    @ObservedObject var detailViewModel: PRDetailViewModel
    let isVisible: Bool
    @State private var showFullDiff = false
    @State private var hasTriggeredLoad = false

    init(pullRequest: PullRequest, detailViewModel: PRDetailViewModel, isVisible: Bool = true, navigationTarget: NotificationTarget? = nil, onBack: (() -> Void)? = nil, onNavigationComplete: (() -> Void)? = nil) {
        self.pullRequest = pullRequest
        self.detailViewModel = detailViewModel
        self.isVisible = isVisible
        self.navigationTarget = navigationTarget
        self.onBack = onBack
        self.onNavigationComplete = onNavigationComplete
    }

    var body: some View {
        ZStack {
            if showFullDiff {
                // Full diff view
                PRDetailView(viewModel: detailViewModel)
            } else {
                // Card-based horizontal paging
                TabView(selection: $detailViewModel.currentCardIndex) {
                    ForEach(Array(detailViewModel.cards.enumerated()), id: \.element.id) { index, card in
                        PRDetailCardView(card: card, viewModel: detailViewModel, onBack: onBack, onShowDiff: { showFullDiff = true })
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea(edges: .bottom)
            }

            // Card indicator (bottom center) - only in card mode
            if !showFullDiff {
                VStack {
                    Spacer()
                    Text(detailViewModel.cardNavigationStatus)
                        .font(.caption.monospaced())
                        .foregroundColor(GruvboxColors.fg4)
                        .padding(.bottom, 6)
                }
            }

            // Back to cards button (in full diff mode)
            if showFullDiff {
                VStack {
                    HStack {
                        Button {
                            showFullDiff = false
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Cards")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(GruvboxColors.aquaLight)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(GruvboxColors.bg1)
                            .cornerRadius(8)
                        }
                        .padding(.leading, 12)
                        .padding(.top, 8)
                        Spacer()
                    }
                    Spacer()
                }
            }

            // Loading overlay
            if detailViewModel.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(GruvboxColors.fg1)
                    .scaleEffect(1.5)
            }
        }
        .background(GruvboxColors.bg0)
        .onChange(of: isVisible) { _, nowVisible in
            // Lazy load: only load details when this PR becomes visible
            if nowVisible && !hasTriggeredLoad {
                hasTriggeredLoad = true
                Task {
                    await detailViewModel.loadDetails()
                }
            }
        }
        .onAppear {
            // Also trigger on appear if already visible (for initial load)
            if isVisible && !hasTriggeredLoad {
                hasTriggeredLoad = true
                Task {
                    await detailViewModel.loadDetails()
                }
            }
        }
        .sheet(isPresented: $detailViewModel.showAddComment, onDismiss: {
            detailViewModel.checkPendingSwap()
        }) {
            AddCommentSheet(viewModel: detailViewModel)
        }
        .sheet(isPresented: $detailViewModel.showAddGeneralComment, onDismiss: {
            detailViewModel.checkPendingSwap()
        }) {
            AddGeneralCommentSheet(viewModel: detailViewModel)
        }
        .onChange(of: navigationTarget) { _, target in
            if let target = target {
                navigateToNotificationTarget(target)
            }
        }
        .onChange(of: detailViewModel.fileDiffs) { _, _ in
            // When diffs are loaded, try to navigate to target
            if let target = navigationTarget {
                navigateToNotificationTarget(target)
            }
        }
    }

    private func navigateToNotificationTarget(_ target: NotificationTarget) {
        // Try to find matching card by commentId first, then by file/line
        for (index, card) in detailViewModel.cards.enumerated() {
            switch card {
            case .reviewThread(_, let comments):
                // Match by commentId if available
                if let commentId = target.commentId,
                   comments.contains(where: { $0.id == commentId }) {
                    detailViewModel.currentCardIndex = index
                    onNavigationComplete?()
                    return
                }
                // Fall back to file path and line matching
                if let filePath = target.filePath, let line = target.line,
                   comments.contains(where: { $0.path == filePath && $0.line == line }) {
                    detailViewModel.currentCardIndex = index
                    onNavigationComplete?()
                    return
                }
            case .generalComment(let comment):
                // Match general comments by commentId
                if let commentId = target.commentId, comment.id == commentId {
                    detailViewModel.currentCardIndex = index
                    onNavigationComplete?()
                    return
                }
            case .description:
                continue
            }
        }
        // No matching card found, stay on description
        onNavigationComplete?()
    }
}

struct AddCommentSheet: View {
    @ObservedObject var viewModel: PRDetailViewModel
    @State private var commentText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // File and line info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adding comment to:")
                        .font(.caption)
                        .foregroundColor(GruvboxColors.fg4)
                    Text(viewModel.addCommentFile)
                        .font(.caption.monospaced())
                        .foregroundColor(GruvboxColors.aquaLight)
                    Text("Line \(viewModel.addCommentLine)")
                        .font(.caption)
                        .foregroundColor(GruvboxColors.fg4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(GruvboxColors.bg1)
                .cornerRadius(8)

                // Comment input
                TextEditor(text: $commentText)
                    .font(.body)
                    .foregroundColor(GruvboxColors.fg1)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(GruvboxColors.bg1)
                    .cornerRadius(8)

                Spacer()
            }
            .padding()
            .background(GruvboxColors.bg0)
            .navigationTitle("New Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(GruvboxColors.bg0, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(GruvboxColors.fg3)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSubmittingComment {
                        ProgressView()
                            .tint(GruvboxColors.fg1)
                    } else {
                        Button("Submit") {
                            Task {
                                let success = await viewModel.submitComment(commentText)
                                if success {
                                    dismiss()
                                }
                            }
                        }
                        .foregroundColor(commentText.isEmpty ? GruvboxColors.fg4 : GruvboxColors.greenLight)
                        .disabled(commentText.isEmpty)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct AddGeneralCommentSheet: View {
    @ObservedObject var viewModel: PRDetailViewModel
    @State private var commentText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // PR info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adding comment to:")
                        .font(.caption)
                        .foregroundColor(GruvboxColors.fg4)
                    Text("PR #\(viewModel.pullRequest.number)")
                        .font(.caption.bold())
                        .foregroundColor(GruvboxColors.aquaLight)
                    Text(viewModel.pullRequest.title)
                        .font(.caption)
                        .foregroundColor(GruvboxColors.fg2)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(GruvboxColors.bg1)
                .cornerRadius(8)

                // Comment input
                TextEditor(text: $commentText)
                    .font(.body)
                    .foregroundColor(GruvboxColors.fg1)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(GruvboxColors.bg1)
                    .cornerRadius(8)

                Spacer()
            }
            .padding()
            .background(GruvboxColors.bg0)
            .navigationTitle("General Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(GruvboxColors.bg0, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(GruvboxColors.fg3)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSubmittingGeneralComment {
                        ProgressView()
                            .tint(GruvboxColors.fg1)
                    } else {
                        Button("Submit") {
                            Task {
                                let success = await viewModel.submitGeneralComment(commentText)
                                if success {
                                    dismiss()
                                }
                            }
                        }
                        .foregroundColor(commentText.isEmpty ? GruvboxColors.fg4 : GruvboxColors.greenLight)
                        .disabled(commentText.isEmpty)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct PRDetailTopBar: View {
    let pr: PullRequest
    @Binding var viewMode: PRViewMode
    var onBack: (() -> Void)?

    var body: some View {
        HStack {
            // Back button
            if let onBack = onBack {
                Button {
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("PRs")
                    }
                    .font(.subheadline)
                    .foregroundColor(GruvboxColors.aquaLight)
                }
            }

            Spacer()

            // View mode toggle
            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = .description
                    }
                } label: {
                    Text("Info")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(viewMode == .description ? GruvboxColors.bg3 : Color.clear)
                        .foregroundColor(viewMode == .description ? GruvboxColors.fg0 : GruvboxColors.fg4)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = .code
                    }
                } label: {
                    Text("Code")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(viewMode == .code ? GruvboxColors.bg3 : Color.clear)
                        .foregroundColor(viewMode == .code ? GruvboxColors.fg0 : GruvboxColors.fg4)
                }
            }
            .background(GruvboxColors.bg1)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(GruvboxColors.bg3, lineWidth: 1)
            )

            Spacer()

            // PR number
            Text("#\(pr.number)")
                .font(.caption.monospaced())
                .foregroundColor(GruvboxColors.fg4)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(GruvboxColors.bg0.opacity(0.95))
    }
}

struct PRDescriptionView: View {
    let pr: PullRequest

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(pr.repositoryFullName)
                        .font(.subheadline)
                        .foregroundColor(GruvboxColors.aquaLight)

                    Text(pr.title)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(GruvboxColors.fg0)

                    HStack {
                        StatusBadge(state: pr.state)

                        Text("by \(pr.user.login)")
                            .font(.caption)
                            .foregroundColor(GruvboxColors.fg3)

                        Spacer()

                        Text(pr.createdAt, style: .date)
                            .font(.caption)
                            .foregroundColor(GruvboxColors.fg4)
                    }

                    // Branch info
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                        Text(pr.head.ref)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                        Text(pr.base.ref)
                            .lineLimit(1)
                    }
                    .font(.caption.monospaced())
                    .foregroundColor(GruvboxColors.purpleLight)
                }
                .padding()
                .background(GruvboxColors.bg1)
                .cornerRadius(12)

                // Description (Markdown rendered)
                if let body = pr.body, !body.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(GruvboxColors.fg2)

                        MarkdownTextView(markdown: body)
                    }
                    .padding()
                    .background(GruvboxColors.bg1)
                    .cornerRadius(12)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundColor(GruvboxColors.fg4)
                        Text("No description provided")
                            .font(.callout)
                            .foregroundColor(GruvboxColors.fg4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(GruvboxColors.bg1)
                    .cornerRadius(12)
                }
            }
            .padding()
            .padding(.top, 50) // Space for top bar
        }
        .background(GruvboxColors.bg0)
    }
}

struct MarkdownTextView: View {
    let markdown: String

    var body: some View {
        GFMView(markdown: markdown, fontSize: 15, textColor: GruvboxColors.fg1)
    }
}

// MARK: - Card-Based Navigation Views

struct PRDetailCardView: View {
    let card: PRCard
    @ObservedObject var viewModel: PRDetailViewModel
    let onBack: (() -> Void)?
    let onShowDiff: (() -> Void)?

    var body: some View {
        switch card {
        case .description:
            PRDescriptionCard(pr: viewModel.pullRequest, onBack: onBack, onShowDiff: onShowDiff)
        case .reviewThread(let thread, let comments):
            PRReviewThreadCard(thread: thread, comments: comments, viewModel: viewModel, onBack: onBack)
        case .generalComment(let comment):
            PRGeneralCommentCard(comment: comment, viewModel: viewModel, onBack: onBack)
        }
    }
}

struct PRDescriptionCard: View {
    let pr: PullRequest
    let onBack: (() -> Void)?
    let onShowDiff: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with back button
                HStack {
                    if let onBack = onBack {
                        Button {
                            onBack()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("PRs")
                            }
                            .font(.subheadline)
                            .foregroundColor(GruvboxColors.aquaLight)
                        }
                    }
                    Spacer()
                    Text("#\(pr.number)")
                        .font(.caption.monospaced())
                        .foregroundColor(GruvboxColors.fg4)
                }
                .padding(.bottom, 8)

                // PR info card
                VStack(alignment: .leading, spacing: 8) {
                    Text(pr.repositoryFullName)
                        .font(.subheadline)
                        .foregroundColor(GruvboxColors.aquaLight)

                    Text(pr.title)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(GruvboxColors.fg0)

                    HStack {
                        StatusBadge(state: pr.state)

                        Text("by \(pr.user.login)")
                            .font(.caption)
                            .foregroundColor(GruvboxColors.fg3)

                        Spacer()

                        Text(pr.createdAt, style: .date)
                            .font(.caption)
                            .foregroundColor(GruvboxColors.fg4)
                    }

                    // Branch info
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                        Text(pr.head.ref)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                        Text(pr.base.ref)
                            .lineLimit(1)
                    }
                    .font(.caption.monospaced())
                    .foregroundColor(GruvboxColors.purpleLight)
                }
                .padding()
                .background(GruvboxColors.bg1)
                .cornerRadius(12)

                // Description
                if let body = pr.body, !body.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(GruvboxColors.fg2)

                        MarkdownTextView(markdown: body)
                    }
                    .padding()
                    .background(GruvboxColors.bg1)
                    .cornerRadius(12)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundColor(GruvboxColors.fg4)
                        Text("No description provided")
                            .font(.callout)
                            .foregroundColor(GruvboxColors.fg4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(GruvboxColors.bg1)
                    .cornerRadius(12)
                }

                // View Full Diff button
                if let onShowDiff = onShowDiff {
                    Button {
                        onShowDiff()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("View Full Diff")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(GruvboxColors.aquaLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(GruvboxColors.bg1)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(GruvboxColors.bg3, lineWidth: 1)
                        )
                    }
                }

                Spacer(minLength: 100)
            }
            .padding()
        }
        .background(GruvboxColors.bg0)
    }
}

struct PRReviewThreadCard: View {
    let thread: ReviewThread
    let comments: [PRComment]
    @ObservedObject var viewModel: PRDetailViewModel
    let onBack: (() -> Void)?

    @State private var showResolveConfirm = false
    @State private var showUnresolveConfirm = false
    @State private var isProcessing = false
    @State private var showReply = false
    @State private var replyText = ""
    @State private var isSubmittingReply = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var firstComment: PRComment? { comments.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Thread header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Review Thread (\(comments.count))")
                                .font(.headline)
                                .foregroundColor(GruvboxColors.fg1)

                            if let path = firstComment?.path {
                                Text(path)
                                    .font(.caption.monospaced())
                                    .foregroundColor(GruvboxColors.aquaLight)
                            }
                        }

                        Spacer()

                        // Resolution badge
                        if thread.isResolved {
                            Text("Resolved")
                                .font(.caption.weight(.medium))
                                .foregroundColor(GruvboxColors.bg0)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GruvboxColors.greenLight)
                                .cornerRadius(6)
                        }
                    }

                    // All comments in thread
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(comment.user.login)
                                    .font(.subheadline.bold())
                                    .foregroundColor(GruvboxColors.aquaLight)

                                Text(comment.createdAt, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(GruvboxColors.fg4)

                                Spacer()
                            }

                            CommentMarkdownView(
                                markdown: comment.body,
                                fontSize: 14,
                                isResolved: thread.isResolved
                            )
                        }
                        .padding()
                        .background(GruvboxColors.bg1)
                        .cornerRadius(8)
                    }

                    // Reply section
                    if showReply {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Write a reply...", text: $replyText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .foregroundColor(GruvboxColors.fg1)
                                .padding(10)
                                .background(GruvboxColors.bg1)
                                .cornerRadius(8)
                                .lineLimit(3...8)

                            HStack {
                                Button("Cancel") {
                                    showReply = false
                                    replyText = ""
                                }
                                .font(.subheadline)
                                .foregroundColor(GruvboxColors.fg4)

                                Spacer()

                                if isSubmittingReply {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(GruvboxColors.fg1)
                                } else {
                                    Button("Send") {
                                        submitReply()
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(replyText.isEmpty ? GruvboxColors.fg4 : GruvboxColors.greenLight)
                                    .disabled(replyText.isEmpty)
                                }
                            }
                        }
                    }

                    // Full file diff
                    if let file = viewModel.fileDiffs.first(where: { $0.filename == firstComment?.path }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("File Changes")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(GruvboxColors.fg3)

                            FullFileContextView(
                                file: file,
                                highlightLine: firstComment?.line,
                                viewModel: viewModel
                            )
                        }
                    }

                    Spacer(minLength: 60)
                }
                .padding()
            }
        .overlay(alignment: .bottomTrailing) {
            // Floating buttons stacked vertically (bottom right)
            VStack(spacing: 8) {
                // Back to PRs button
                if let onBack = onBack {
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("PRs")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(GruvboxColors.aquaLight)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(GruvboxColors.bg2.opacity(0.99))
                        .cornerRadius(8)
                    }
                }

                // Reply button
                Button {
                    showReply.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrowshape.turn.up.left")
                        Text("Reply")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(GruvboxColors.aquaLight)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(GruvboxColors.bg2.opacity(0.99))
                    .cornerRadius(8)
                }

                // Resolve/Unresolve button
                if isProcessing {
                    ProgressView()
                        .tint(GruvboxColors.fg1)
                        .padding(.vertical, 10)
                } else if thread.isResolved && thread.viewerCanUnresolve {
                    Button {
                        showUnresolveConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward.circle")
                            Text("Unresolve")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(GruvboxColors.orangeLight)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(GruvboxColors.bg2.opacity(0.99))
                        .cornerRadius(8)
                    }
                } else if !thread.isResolved && thread.viewerCanResolve {
                    Button {
                        showResolveConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                            Text("Resolve")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(GruvboxColors.greenLight)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(GruvboxColors.bg2.opacity(0.99))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
        .background(GruvboxColors.bg0)
        .alert("Resolve Thread?", isPresented: $showResolveConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Resolve") {
                resolveThread()
            }
        } message: {
            Text("Mark this review thread as resolved?")
        }
        .alert("Unresolve Thread?", isPresented: $showUnresolveConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Unresolve") {
                unresolveThread()
            }
        } message: {
            Text("Mark this review thread as unresolved?")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func resolveThread() {
        guard let comment = firstComment else { return }
        isProcessing = true
        Task {
            let success = await viewModel.resolveThread(for: comment)
            await MainActor.run {
                isProcessing = false
                if !success {
                    errorMessage = viewModel.error ?? "Failed to resolve thread"
                    showError = true
                }
                // On success, card will be removed automatically since resolved threads are filtered out
            }
        }
    }

    private func unresolveThread() {
        guard let comment = firstComment else { return }
        isProcessing = true
        Task {
            let success = await viewModel.unresolveThread(for: comment)
            await MainActor.run {
                isProcessing = false
                if !success {
                    errorMessage = viewModel.error ?? "Failed to unresolve thread"
                    showError = true
                }
            }
        }
    }

    private func submitReply() {
        guard !replyText.isEmpty, let comment = firstComment else { return }
        isSubmittingReply = true
        Task {
            let success = await viewModel.replyToComment(comment, body: replyText)
            await MainActor.run {
                isSubmittingReply = false
                if success {
                    showReply = false
                    replyText = ""
                } else {
                    errorMessage = viewModel.error ?? "Failed to submit reply"
                    showError = true
                }
            }
        }
    }
}

struct PRGeneralCommentCard: View {
    let comment: IssueComment
    @ObservedObject var viewModel: PRDetailViewModel
    let onBack: (() -> Void)?

    @State private var showDeleteConfirm = false
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Discussion Comment")
                    .font(.headline)
                    .foregroundColor(GruvboxColors.fg1)

                // Comment body
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(comment.user.login)
                            .font(.subheadline.bold())
                            .foregroundColor(GruvboxColors.aquaLight)

                        Text(comment.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(GruvboxColors.fg4)

                        Spacer()
                    }

                    CommentMarkdownView(
                        markdown: comment.body,
                        fontSize: 14
                    )
                }
                .padding()
                .background(GruvboxColors.bg1)
                .cornerRadius(8)

                Spacer(minLength: 60)
            }
            .padding()
        }
        .overlay(alignment: .bottomTrailing) {
            // Floating buttons (bottom right)
            VStack(spacing: 8) {
                // Back to PRs button
                if let onBack = onBack {
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("PRs")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(GruvboxColors.aquaLight)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(GruvboxColors.bg2.opacity(0.99))
                        .cornerRadius(8)
                    }
                }

                // Delete button
                if isProcessing {
                    ProgressView()
                        .tint(GruvboxColors.fg1)
                } else {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(GruvboxColors.redLight)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(GruvboxColors.bg2.opacity(0.99))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
        .background(GruvboxColors.bg0)
        .alert("Delete Comment?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteComment()
            }
        } message: {
            Text("Permanently delete this comment from GitHub?")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func deleteComment() {
        isProcessing = true
        Task {
            let success = await viewModel.deleteIssueComment(comment)
            await MainActor.run {
                isProcessing = false
                if !success {
                    errorMessage = viewModel.error ?? "Failed to delete comment"
                    showError = true
                }
                // On success, the card will automatically disappear
                // because the comment is removed from issueComments
            }
        }
    }
}

struct FullFileContextView: View {
    let file: FileDiff
    let highlightLine: Int?
    @ObservedObject var viewModel: PRDetailViewModel

    // Track selected line within this view
    @State private var selectedLineKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // File name header
            HStack {
                Text(file.filename)
                    .font(.caption.monospaced())
                    .foregroundColor(GruvboxColors.fg4)
                Spacer()
                Text("+\(file.additions) -\(file.deletions)")
                    .font(.caption.monospaced())
                    .foregroundColor(GruvboxColors.fg4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(GruvboxColors.bg2)

            // All hunks
            ForEach(Array(file.hunks.enumerated()), id: \.element.id) { hunkIndex, hunk in
                // Hunk header
                Text(hunk.header)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(GruvboxColors.fg4)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GruvboxColors.bg1)

                // Hunk lines
                ForEach(Array(hunk.lines.enumerated()), id: \.element.id) { lineIndex, line in
                    let lineKey = "\(file.filename)-\(hunkIndex)-\(lineIndex)"
                    let isSelected = selectedLineKey == lineKey
                    let isHighlighted = isLineHighlighted(line)

                    HStack(spacing: 0) {
                        Text(line.content)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(line.gruvboxTextColor)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Show + button when selected
                        if isSelected {
                            Button {
                                openCommentDialog(for: line)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(GruvboxColors.aquaLight)
                            }
                            .padding(.trailing, 4)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(
                        isSelected
                            ? GruvboxColors.aquaLight.opacity(0.2)
                            : (isHighlighted
                                ? GruvboxColors.yellow.opacity(0.4)
                                : line.gruvboxBackgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(GruvboxColors.aquaLight, lineWidth: isSelected ? 1 : 0)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleLineTap(lineKey: lineKey, line: line)
                    }
                }
            }
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(GruvboxColors.bg3, lineWidth: 1)
        )
    }

    private func isLineHighlighted(_ line: DiffLine) -> Bool {
        guard let highlightLine = highlightLine else { return false }
        return line.newLineNumber == highlightLine || line.oldLineNumber == highlightLine
    }

    private func handleLineTap(lineKey: String, line: DiffLine) {
        if selectedLineKey == lineKey {
            // Already selected - open comment dialog
            openCommentDialog(for: line)
        } else {
            // Select this line
            selectedLineKey = lineKey
        }
    }

    private func openCommentDialog(for line: DiffLine) {
        let lineNumber = line.newLineNumber ?? line.oldLineNumber ?? 0
        viewModel.prepareAddComment(file: file.filename, line: lineNumber)
        selectedLineKey = nil
    }
}

#Preview {
    PRPageView(viewModel: PRListViewModel())
}

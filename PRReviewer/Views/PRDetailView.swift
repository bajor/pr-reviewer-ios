import SwiftUI

struct PRDetailView: View {
    @ObservedObject var viewModel: PRDetailViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    PRHeaderView(pr: viewModel.pullRequest, viewModel: viewModel)

                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(GruvboxColors.fg1)
                                .padding()
                            Spacer()
                        }
                    } else if let error = viewModel.error {
                        Text(error)
                            .foregroundColor(GruvboxColors.redLight)
                            .padding()
                    } else {
                        IssueCommentsSection(comments: viewModel.issueComments, viewModel: viewModel)

                        ForEach(Array(viewModel.fileDiffs.enumerated()), id: \.element.id) { fileIndex, file in
                            DiffFileView(
                                file: file,
                                fileIndex: fileIndex,
                                viewModel: viewModel
                            )
                        }
                    }

                    Spacer(minLength: 100)
                }
            }
            .background(GruvboxColors.bg0)
            .onChange(of: viewModel.currentItemIndex) { _, _ in
                if let id = viewModel.currentScrollId {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
}

struct PRHeaderView: View {
    let pr: PullRequest
    @ObservedObject var viewModel: PRDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and repo info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("#\(pr.number)")
                        .font(.headline.monospaced())
                        .foregroundColor(GruvboxColors.fg4)

                    Text(pr.repositoryFullName)
                        .font(.subheadline)
                        .foregroundColor(GruvboxColors.aquaLight)

                    Spacer()

                    Label(pr.user.login, systemImage: "person.circle.fill")
                        .font(.caption)
                        .foregroundColor(GruvboxColors.fg2)
                }

                Text(pr.title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(GruvboxColors.fg0)

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

            // Status banner (checks and branch sync)
            PRStatusBannerView(viewModel: viewModel)

            // Add General Comment button
            Button {
                viewModel.showAddGeneralComment = true
            } label: {
                HStack {
                    Image(systemName: "text.bubble")
                    Text("Add Comment")
                }
                .font(.caption.weight(.medium))
                .foregroundColor(GruvboxColors.aquaLight)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(GruvboxColors.bg2)
                .cornerRadius(8)
            }

            // Full description with markdown
            if let body = pr.body, !body.isEmpty {
                Rectangle()
                    .fill(GruvboxColors.bg3)
                    .frame(height: 1)

                PRMarkdownView(markdown: body)
            }

            Rectangle()
                .fill(GruvboxColors.bg3)
                .frame(height: 1)
        }
        .padding()
        .background(GruvboxColors.bg0)
    }
}

/// Shows GitHub Actions check status and branch sync status
struct PRStatusBannerView: View {
    @ObservedObject var viewModel: PRDetailViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Check runs status
            if let checks = viewModel.checkRunsStatus {
                HStack(spacing: 4) {
                    Image(systemName: checks.overallStatus.icon)
                        .foregroundColor(checkColor(for: checks.overallStatus))

                    Text(checksLabel(for: checks))
                        .font(.caption)
                        .foregroundColor(GruvboxColors.fg2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(checkBackground(for: checks.overallStatus))
                .cornerRadius(6)
            }

            // Branch sync status
            if let comparison = viewModel.branchComparison {
                HStack(spacing: 4) {
                    Image(systemName: comparison.isBehind ? "arrow.down.circle" : "checkmark.circle")
                        .foregroundColor(comparison.isBehind ? GruvboxColors.orangeLight : GruvboxColors.greenLight)

                    Text(comparison.statusLabel)
                        .font(.caption)
                        .foregroundColor(GruvboxColors.fg2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(comparison.isBehind ? GruvboxColors.bg2 : GruvboxColors.bg1)
                .cornerRadius(6)
            }

            Spacer()
        }
    }

    private func checkColor(for status: CheckRunsStatus.CheckStatus) -> Color {
        switch status {
        case .none: return GruvboxColors.fg4
        case .pending: return GruvboxColors.yellowLight
        case .passed: return GruvboxColors.greenLight
        case .failed: return GruvboxColors.redLight
        }
    }

    private func checkBackground(for status: CheckRunsStatus.CheckStatus) -> Color {
        switch status {
        case .failed: return GruvboxColors.redLight.opacity(0.15)
        case .passed: return GruvboxColors.greenLight.opacity(0.15)
        default: return GruvboxColors.bg2
        }
    }

    private func checksLabel(for checks: CheckRunsStatus) -> String {
        switch checks.overallStatus {
        case .none:
            return "No checks"
        case .pending:
            return "\(checks.pending) running"
        case .passed:
            return "\(checks.successful)/\(checks.total) passed"
        case .failed:
            return "\(checks.failed) failed"
        }
    }
}

struct PRMarkdownView: View {
    let markdown: String
    let fontSize: CGFloat

    init(markdown: String, fontSize: CGFloat = 14) {
        self.markdown = markdown
        self.fontSize = fontSize
    }

    var body: some View {
        GFMView(markdown: markdown, fontSize: fontSize, textColor: GruvboxColors.fg1)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct CommentMarkdownView: View {
    let markdown: String
    let fontSize: CGFloat
    let isResolved: Bool

    init(markdown: String, fontSize: CGFloat = 14, isResolved: Bool = false) {
        self.markdown = markdown
        self.fontSize = fontSize
        self.isResolved = isResolved
    }

    var body: some View {
        GFMView(
            markdown: markdown,
            fontSize: fontSize,
            textColor: isResolved ? GruvboxColors.fg4 : GruvboxColors.fg1,
            isResolved: isResolved
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct IssueCommentsSection: View {
    let comments: [IssueComment]
    @ObservedObject var viewModel: PRDetailViewModel

    var body: some View {
        if !comments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Discussion")
                    .font(.headline)
                    .foregroundColor(GruvboxColors.fg1)
                    .padding(.horizontal, 4)

                ForEach(comments) { comment in
                    GeneralCommentView(comment: comment, viewModel: viewModel)
                }

                Rectangle()
                    .fill(GruvboxColors.bg3)
                    .frame(height: 1)
                    .padding(.vertical)
            }
            .background(GruvboxColors.bg0)
        }
    }
}

struct GeneralCommentView: View {
    let comment: IssueComment
    @ObservedObject var viewModel: PRDetailViewModel

    @State private var showActionSheet = false
    @State private var isProcessingAction = false

    private var isFolded: Bool {
        viewModel.isCommentFolded(comment.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.user.login)
                    .font(.caption.bold())
                    .foregroundColor(GruvboxColors.aquaLight)

                Text(comment.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(GruvboxColors.fg4)

                Spacer()

                if isProcessingAction {
                    ProgressView()
                        .scaleEffect(0.5)
                        .tint(GruvboxColors.fg4)
                } else {
                    // Fold/unfold indicator
                    Image(systemName: isFolded ? "chevron.down" : "chevron.up")
                        .font(.caption2)
                        .foregroundColor(GruvboxColors.fg4)
                }
            }

            if isFolded {
                // Show preview when folded
                Text(String(comment.body.prefix(60)) + (comment.body.count > 60 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(GruvboxColors.fg4)
                    .lineLimit(1)
            } else {
                CommentMarkdownView(markdown: comment.body)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(isFolded ? GruvboxColors.bg0 : GruvboxColors.bg1)
        .cornerRadius(6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isFolded {
                viewModel.toggleCommentFolded(comment.id)
            } else {
                showActionSheet = true
            }
        }
        .confirmationDialog("Comment Actions", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("Fold") {
                viewModel.foldComment(comment.id)
            }

            Button("Delete", role: .destructive) {
                deleteComment()
            }

            Button("Cancel", role: .cancel) { }
        }
    }

    private func deleteComment() {
        isProcessingAction = true
        Task {
            _ = await viewModel.deleteIssueComment(comment)
            await MainActor.run {
                isProcessingAction = false
            }
        }
    }
}

#Preview {
    PRDetailView(viewModel: PRDetailViewModel(pullRequest: PullRequest(
        id: 1,
        number: 123,
        title: "Test PR",
        body: "This is a test",
        state: "open",
        user: GitHubUser(login: "testuser"),
        head: GitRef(ref: "feature", sha: "abc123", repo: nil),
        base: GitRef(ref: "main", sha: "def456", repo: nil),
        createdAt: Date(),
        updatedAt: Date()
    )))
}

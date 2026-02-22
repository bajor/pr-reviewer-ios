import SwiftUI

struct DiffLineView: View {
    let line: DiffLine
    let filename: String
    let comments: [PRComment]
    let fileIndex: Int
    let hunkIndex: Int
    let lineIndex: Int
    @ObservedObject var viewModel: PRDetailViewModel

    // Unique key for this line
    private var lineKey: String {
        "\(fileIndex)-\(hunkIndex)-\(lineIndex)"
    }

    private var isSelected: Bool {
        viewModel.selectedLineKey == lineKey
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Text(line.content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(line.gruvboxTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)

                // Show + button when selected
                if isSelected {
                    Button {
                        openCommentDialog()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(GruvboxColors.aquaLight)
                    }
                    .padding(.trailing, 8)
                    .padding(.vertical, 2)
                }
            }
            .background(line.gruvboxBackgroundColor)
            // Selection frame
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(GruvboxColors.aquaLight, lineWidth: isSelected ? 2 : 0)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }

            if !comments.isEmpty {
                CommentsBlockView(
                    comments: comments,
                    viewModel: viewModel
                )
            }
        }
        .id("line-\(lineIndex)")
    }

    private func handleTap() {
        if isSelected {
            // Already selected - open comment dialog
            openCommentDialog()
        } else {
            // Select this line
            viewModel.selectedLineKey = lineKey
        }
    }

    private func openCommentDialog() {
        // Get the line number for the comment
        let lineNumber = line.newLineNumber ?? line.oldLineNumber ?? 0
        viewModel.prepareAddComment(file: filename, line: lineNumber)
        // Clear selection after opening dialog
        viewModel.selectedLineKey = nil
    }
}

struct CommentsBlockView: View {
    let comments: [PRComment]
    @ObservedObject var viewModel: PRDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top separator line
            Rectangle()
                .fill(GruvboxColors.yellow)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(comments) { comment in
                    InlineCommentView(comment: comment, viewModel: viewModel)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)

            // Bottom separator line
            Rectangle()
                .fill(GruvboxColors.yellow)
                .frame(height: 1)
        }
        .background(GruvboxColors.commentBg)
    }
}

struct InlineCommentView: View {
    let comment: PRComment
    @ObservedObject var viewModel: PRDetailViewModel

    @State private var showActionSheet = false
    @State private var showReply = false
    @State private var replyText = ""
    @State private var isSubmitting = false
    @State private var isProcessingAction = false

    private var isResolved: Bool {
        viewModel.isThreadResolved(comment)
    }

    private var isFolded: Bool {
        viewModel.isCommentFolded(comment.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header (simplified - actions via tap menu)
            HStack {
                Text(comment.user.login)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(GruvboxColors.aquaLight)

                Text(comment.createdAt, style: .relative)
                    .font(.system(size: 9))
                    .foregroundColor(GruvboxColors.fg4)

                // Resolved badge
                if isResolved {
                    Text("Resolved")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(GruvboxColors.bg0)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(GruvboxColors.greenLight)
                        .cornerRadius(4)
                }

                Spacer()

                // Fold indicator
                Image(systemName: isFolded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 8))
                    .foregroundColor(GruvboxColors.fg4)

                // Loading indicator for actions
                if isProcessingAction {
                    ProgressView()
                        .scaleEffect(0.5)
                        .tint(GruvboxColors.fg4)
                }
            }

            if isFolded {
                // Show preview when folded
                Text(String(comment.body.prefix(50)) + (comment.body.count > 50 ? "..." : ""))
                    .font(.system(size: 9))
                    .foregroundColor(GruvboxColors.fg4)
                    .lineLimit(1)
            } else {
                // Comment body with markdown (dimmed if resolved)
                CommentMarkdownView(
                    markdown: comment.body,
                    fontSize: 10,
                    isResolved: isResolved
                )

                // Reply input
                if showReply {
                    VStack(spacing: 4) {
                        TextField("Reply...", text: $replyText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 10))
                            .lineLimit(2...4)

                        HStack {
                            Button("Cancel") {
                                showReply = false
                                replyText = ""
                            }
                            .foregroundColor(GruvboxColors.fg4)

                            Spacer()

                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(GruvboxColors.fg1)
                            } else {
                                Button("Reply") {
                                    submitReply()
                                }
                                .foregroundColor(GruvboxColors.greenLight)
                                .disabled(replyText.isEmpty)
                            }
                        }
                        .font(.system(size: 9))
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, isFolded ? 4 : 6)
        .background(isFolded ? GruvboxColors.bg1 : (isResolved ? GruvboxColors.bg1 : GruvboxColors.bg2))
        .cornerRadius(4)
        .opacity(isResolved ? 0.8 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            if isFolded {
                viewModel.toggleCommentFolded(comment.id)
            } else {
                showActionSheet = true
            }
        }
        .confirmationDialog("Comment Actions", isPresented: $showActionSheet, titleVisibility: .visible) {
            // Fold/Collapse locally
            Button("Fold") {
                viewModel.foldComment(comment.id)
            }

            // Reply
            Button("Reply") {
                showReply = true
            }

            // Resolve thread - only if can resolve
            if viewModel.canResolveComment(comment) {
                Button("Resolve Thread") {
                    resolveThread()
                }
            }

            // Unresolve thread - only if can unresolve
            if viewModel.canUnresolveComment(comment) {
                Button("Unresolve Thread") {
                    unresolveThread()
                }
            }

            // Hide on GitHub (minimize)
            Button("Hide on GitHub", role: .destructive) {
                hideComment()
            }

            Button("Cancel", role: .cancel) { }
        }
    }

    private func submitReply() {
        guard !replyText.isEmpty else { return }
        isSubmitting = true

        Task {
            let success = await viewModel.replyToComment(comment, body: replyText)
            await MainActor.run {
                isSubmitting = false
                if success {
                    showReply = false
                    replyText = ""
                }
            }
        }
    }

    private func resolveThread() {
        isProcessingAction = true
        Task {
            _ = await viewModel.resolveThread(for: comment)
            await MainActor.run {
                isProcessingAction = false
            }
        }
    }

    private func unresolveThread() {
        isProcessingAction = true
        Task {
            _ = await viewModel.unresolveThread(for: comment)
            await MainActor.run {
                isProcessingAction = false
            }
        }
    }

    private func hideComment() {
        isProcessingAction = true
        Task {
            _ = await viewModel.minimizeComment(comment)
            await MainActor.run {
                isProcessingAction = false
            }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        DiffLineView(
            line: DiffLine(
                type: .addition,
                content: "let x = 42",
                oldLineNumber: nil,
                newLineNumber: 10
            ),
            filename: "test.swift",
            comments: [],
            fileIndex: 0,
            hunkIndex: 0,
            lineIndex: 0,
            viewModel: PRDetailViewModel(pullRequest: PullRequest(
                id: 1, number: 1, title: "Test", body: nil, state: "open",
                user: GitHubUser(login: "test"),
                head: GitRef(ref: "main", sha: "", repo: nil),
                base: GitRef(ref: "main", sha: "", repo: nil),
                createdAt: Date(), updatedAt: Date()
            ))
        )
    }
}

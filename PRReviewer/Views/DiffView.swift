import SwiftUI

struct DiffFileView: View {
    let file: FileDiff
    let fileIndex: Int
    @ObservedObject var viewModel: PRDetailViewModel
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                FileHeaderView(file: file, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(Array(file.hunks.enumerated()), id: \.element.id) { hunkIndex, hunk in
                    DiffHunkView(
                        hunk: hunk,
                        filename: file.filename,
                        fileIndex: fileIndex,
                        hunkIndex: hunkIndex,
                        viewModel: viewModel
                    )
                    .id("hunk-\(fileIndex)-\(hunkIndex)")
                }
            }
        }
    }
}

struct FileHeaderView: View {
    let file: FileDiff
    let isExpanded: Bool

    var body: some View {
        HStack {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption)
                .foregroundColor(GruvboxColors.fg4)
                .frame(width: 16)

            FileStatusIcon(status: file.status)

            Text(file.filename)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(GruvboxColors.fg1)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            HStack(spacing: 4) {
                if file.additions > 0 {
                    Text("+\(file.additions)")
                        .foregroundColor(GruvboxColors.greenLight)
                }
                if file.deletions > 0 {
                    Text("-\(file.deletions)")
                        .foregroundColor(GruvboxColors.redLight)
                }
            }
            .font(.caption.monospaced())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(GruvboxColors.bg2)
    }
}

struct FileStatusIcon: View {
    let status: FileStatus

    var body: some View {
        Group {
            switch status {
            case .added:
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(GruvboxColors.greenLight)
            case .removed:
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(GruvboxColors.redLight)
            case .modified:
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(GruvboxColors.orangeLight)
            case .renamed:
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(GruvboxColors.blueLight)
            default:
                Image(systemName: "circle.fill")
                    .foregroundColor(GruvboxColors.fg4)
            }
        }
        .font(.caption)
    }
}

struct DiffHunkView: View {
    let hunk: DiffHunk
    let filename: String
    let fileIndex: Int
    let hunkIndex: Int
    @ObservedObject var viewModel: PRDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(hunk.lines.enumerated()), id: \.element.id) { lineIndex, line in
                // Show ALL lines - full file view
                let comments = viewModel.commentsFor(filename: filename, line: line)

                DiffLineView(
                    line: line,
                    filename: filename,
                    comments: comments,
                    fileIndex: fileIndex,
                    hunkIndex: hunkIndex,
                    lineIndex: lineIndex,
                    viewModel: viewModel
                )
                .id("line-\(fileIndex)-\(hunkIndex)-\(lineIndex)")
            }
        }
    }
}

#Preview {
    DiffFileView(
        file: FileDiff(
            filename: "test.swift",
            status: .modified,
            hunks: [],
            additions: 10,
            deletions: 5
        ),
        fileIndex: 0,
        viewModel: PRDetailViewModel(pullRequest: PullRequest(
            id: 1, number: 1, title: "Test", body: nil, state: "open",
            htmlUrl: "", user: GitHubUser(id: 1, login: "test", avatarUrl: nil),
            head: GitRef(ref: "main", sha: "", repo: nil),
            base: GitRef(ref: "main", sha: "", repo: nil),
            createdAt: Date(), updatedAt: Date()
        ))
    )
}

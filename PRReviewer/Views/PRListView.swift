import SwiftUI

struct PRListHorizontalView: View {
    let pullRequests: [PullRequest]
    let onSelectPR: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(pullRequests.enumerated()), id: \.element.id) { index, pr in
                    PRCardView(pr: pr)
                        .onTapGesture {
                            onSelectPR(index)
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60) // Space for top bar
            .padding(.bottom, 40)
        }
    }
}

struct PRCardView: View {
    let pr: PullRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Repo name
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(GruvboxColors.aquaLight)
                Text(pr.repositoryFullName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(GruvboxColors.aquaLight)
            }

            // PR number and status
            HStack {
                Text("#\(pr.number)")
                    .font(.caption.monospaced())
                    .foregroundColor(GruvboxColors.fg4)

                Spacer()

                StatusBadge(state: pr.state)
            }

            // PR Title
            Text(pr.title)
                .font(.headline)
                .foregroundColor(GruvboxColors.fg0)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // PR Description
            if let body = pr.body, !body.isEmpty {
                Text(body)
                    .font(.callout)
                    .foregroundColor(GruvboxColors.fg3)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Author and date
            HStack {
                Label(pr.user.login, systemImage: "person.circle.fill")
                    .font(.caption)
                    .foregroundColor(GruvboxColors.fg4)

                Spacer()

                Text(pr.updatedAt, style: .relative)
                    .font(.caption2)
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
            .font(.caption2.monospaced())
            .foregroundColor(GruvboxColors.purpleLight)

            // Tap to open indicator
            HStack {
                Spacer()
                Text("Tap to open")
                    .font(.caption2)
                    .foregroundColor(GruvboxColors.yellowLight)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(GruvboxColors.yellowLight)
            }
        }
        .padding(16)
        .frame(width: 300, height: 320)
        .background(GruvboxColors.bg1)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GruvboxColors.bg3, lineWidth: 1)
        )
    }
}

struct StatusBadge: View {
    let state: String

    var body: some View {
        Text(state.capitalized)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(GruvboxColors.bg0)
            .cornerRadius(4)
    }

    var backgroundColor: Color {
        switch state.lowercased() {
        case "open": return GruvboxColors.greenLight
        case "closed": return GruvboxColors.redLight
        case "merged": return GruvboxColors.purpleLight
        default: return GruvboxColors.fg4
        }
    }
}

#Preview {
    PRListHorizontalView(
        pullRequests: [
            PullRequest(
                id: 1,
                number: 123,
                title: "Add new feature for user authentication",
                body: "This PR adds OAuth2 support and improves the login flow with better error handling.",
                state: "open",
                user: GitHubUser(login: "testuser"),
                head: GitRef(ref: "feature/auth", sha: "abc123", repo: nil),
                base: GitRef(ref: "main", sha: "def456", repo: nil),
                createdAt: Date(),
                updatedAt: Date()
            )
        ],
        onSelectPR: { _ in }
    )
    .background(Color(.systemGray6))
}

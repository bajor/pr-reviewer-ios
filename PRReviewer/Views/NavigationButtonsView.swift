import SwiftUI

struct NavigationButtonsView: View {
    @ObservedObject var viewModel: PRDetailViewModel

    var body: some View {
        HStack {
            VStack {
                Spacer()

                VStack(spacing: 0) {
                    NavButton(
                        systemName: "chevron.up",
                        action: { viewModel.navigateToPrevious() },
                        isEnabled: viewModel.canNavigatePrevious
                    )

                    Text(viewModel.navigationStatus)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(GruvboxColors.fg4)
                        .frame(width: 50)
                        .padding(.vertical, 4)
                        .background(GruvboxColors.bg2)

                    NavButton(
                        systemName: "chevron.down",
                        action: { viewModel.navigateToNext() },
                        isEnabled: viewModel.canNavigateNext
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GruvboxColors.bg4, lineWidth: 1)
                )

                Spacer()
            }
            .padding(.leading, 4)

            Spacer()
        }
    }
}

struct NavButton: View {
    let systemName: String
    let action: () -> Void
    let isEnabled: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.weight(.semibold))
                .frame(width: 50, height: 50)
                .background(GruvboxColors.bg2)
                .foregroundColor(isEnabled ? GruvboxColors.orangeLight : GruvboxColors.bg4)
        }
        .disabled(!isEnabled)
    }
}

#Preview {
    NavigationButtonsView(viewModel: PRDetailViewModel(pullRequest: PullRequest(
        id: 1, number: 1, title: "Test", body: nil, state: "open",
        htmlUrl: "", user: GitHubUser(id: 1, login: "test", avatarUrl: nil),
        head: GitRef(ref: "main", sha: "", repo: nil),
        base: GitRef(ref: "main", sha: "", repo: nil),
        createdAt: Date(), updatedAt: Date()
    )))
}

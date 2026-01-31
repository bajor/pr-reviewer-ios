import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var prListViewModel = PRListViewModel()
    @State private var showSettings = false

    var body: some View {
        Group {
            if appState.hasValidCredentials {
                MainContentView(viewModel: prListViewModel, showSettings: $showSettings)
                    .onAppear {
                        prListViewModel.startMonitoring()
                    }
                    .onDisappear {
                        prListViewModel.stopMonitoring()
                    }
            } else {
                SettingsRequiredView(showSettings: $showSettings)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onSave: {
                appState.checkCredentials()
            })
        }
    }
}

struct MainContentView: View {
    @ObservedObject var viewModel: PRListViewModel
    @Binding var showSettings: Bool

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.pullRequests.isEmpty {
                LoadingView()
            } else if let error = viewModel.error, viewModel.pullRequests.isEmpty {
                ErrorView(message: error) {
                    Task {
                        await viewModel.refreshAll()
                    }
                }
            } else if viewModel.pullRequests.isEmpty {
                EmptyPRView()
            } else {
                // Horizontal scrolling through everything
                HorizontalAppView(viewModel: viewModel)
            }

            // Settings button overlay (top right)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .font(.body)
                            .foregroundColor(GruvboxColors.fg2)
                            .padding(10)
                            .background(GruvboxColors.bg0.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 12)
                    .padding(.top, 20)
                }
                Spacer()
            }
        }
    }
}


struct HorizontalAppView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: PRListViewModel
    @StateObject private var detailViewModelStore = PRDetailViewModelStore()
    @State private var currentPage = 1  // Start on PR list (page 1)
    @State private var previousPage = 1  // Track previous page for swipe prevention
    @State private var pendingTarget: NotificationTarget?
    @State private var allowPRNavigation = false  // Flag to allow programmatic navigation to PR details

    var body: some View {
        TabView(selection: $currentPage) {
            // Page 0: Notification History (swipe left from PR list)
            NotificationHistoryView { target in
                navigateToTarget(target)
            }
            .tag(0)

            // Page 1: PR List (horizontal cards)
            PRListHorizontalView(
                pullRequests: viewModel.pullRequests,
                onSelectPR: { index in
                    viewModel.selectPR(at: index)
                    allowPRNavigation = true
                    withAnimation {
                        currentPage = index + 2  // PR details start at page 2
                    }
                }
            )
            .tag(1)

            // Pages 2+: Individual PR details with back button
            ForEach(Array(viewModel.pullRequests.enumerated()), id: \.element.id) { index, pr in
                PRDetailContainerView(
                    pullRequest: pr,
                    detailViewModel: detailViewModelStore.viewModel(for: pr),
                    isVisible: currentPage == index + 2,
                    navigationTarget: currentPage == index + 2 ? pendingTarget : nil,
                    onBack: {
                        withAnimation {
                            currentPage = 1  // Back to PR list
                        }
                    },
                    onNavigationComplete: {
                        pendingTarget = nil
                    }
                )
                    .tag(index + 2)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .bottom)
        .background(GruvboxColors.bg0)
        .onChange(of: currentPage) { oldValue, newValue in
            // Prevent swiping from PR list (page 1) to PR details (page 2+)
            // Only allow if triggered programmatically (tap or notification)
            if oldValue == 1 && newValue >= 2 && !allowPRNavigation {
                // Revert to PR list
                currentPage = 1
                return
            }
            // Reset the flag after any navigation
            allowPRNavigation = false
            previousPage = newValue
        }
        .onChange(of: appState.pendingNavigation) { _, target in
            if let target = target {
                navigateToTarget(target)
            }
        }
    }

    private func navigateToTarget(_ target: NotificationTarget) {
        // Find the PR with matching number and repo
        if let index = viewModel.pullRequests.firstIndex(where: {
            $0.number == target.prNumber && $0.repositoryFullName == target.repoFullName
        }) {
            pendingTarget = target
            allowPRNavigation = true
            withAnimation {
                currentPage = index + 2  // PR details start at page 2
            }
        }
        appState.clearPendingNavigation()
    }
}

struct SettingsRequiredView: View {
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "gear.badge")
                .font(.system(size: 60))
                .foregroundColor(GruvboxColors.fg4)

            Text("Setup Required")
                .font(.title2.bold())
                .foregroundColor(GruvboxColors.fg0)

            Text("Please configure your GitHub credentials to view pull requests.")
                .font(.body)
                .foregroundColor(GruvboxColors.fg3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showSettings = true
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(GruvboxColors.orangeLight)
                    .foregroundColor(GruvboxColors.bg0)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GruvboxColors.bg0)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(GruvboxColors.fg1)
            Text("Loading pull requests...")
                .foregroundColor(GruvboxColors.fg3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GruvboxColors.bg0)
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(GruvboxColors.orangeLight)

            Text("Something went wrong")
                .font(.headline)
                .foregroundColor(GruvboxColors.fg0)

            Text(message)
                .font(.caption)
                .foregroundColor(GruvboxColors.fg4)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry", action: retryAction)
                .foregroundColor(GruvboxColors.bg0)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(GruvboxColors.aquaLight)
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GruvboxColors.bg0)
    }
}

struct EmptyPRView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(GruvboxColors.greenLight)

            Text("No open pull requests")
                .font(.headline)
                .foregroundColor(GruvboxColors.fg0)

            Text("You're all caught up!")
                .foregroundColor(GruvboxColors.fg3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GruvboxColors.bg0)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

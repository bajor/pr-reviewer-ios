import SwiftUI
import UserNotifications

@main
struct PRReviewerApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Initialize notification manager to set up delegate
        _ = NotificationManager.shared
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    setupNotificationHandler()
                }
        }
    }

    private func requestNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                print("Notification permission: \(granted ? "granted" : "denied")")
            } catch {
                print("Notification permission error: \(error)")
            }
        }
    }

    private func setupNotificationHandler() {
        NotificationManager.shared.onNotificationTapped = { [weak appState] target in
            appState?.navigateToTarget(target)
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var hasValidCredentials: Bool = false
    @Published var pendingNavigation: NotificationTarget?

    private let accountManager = AccountManager.shared

    init() {
        checkCredentials()
    }

    func checkCredentials() {
        hasValidCredentials = accountManager.hasValidCredentials
    }

    func navigateToTarget(_ target: NotificationTarget) {
        pendingNavigation = target
    }

    func clearPendingNavigation() {
        pendingNavigation = nil
    }
}

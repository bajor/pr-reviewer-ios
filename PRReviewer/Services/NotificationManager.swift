import Foundation
import UserNotifications

// Deep link target for navigation
struct NotificationTarget: Codable, Equatable {
    let prNumber: Int
    let repoFullName: String
    let filePath: String?
    let line: Int?
    let commentId: Int?
}

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    // Callback when notification is tapped
    var onNotificationTapped: ((NotificationTarget) -> Void)?

    // History manager for storing notifications
    private let historyManager = NotificationHistoryManager.shared

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                print("Notification permission error: \(error)")
                return false
            }
        }

        return settings.authorizationStatus == .authorized
    }

    func sendNotification(title: String, body: String, playSound: Bool, target: NotificationTarget? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = playSound ? .default : nil

        // Add deep link data
        if let target = target,
           let data = try? JSONEncoder().encode(target),
           let json = String(data: data, encoding: .utf8) {
            content.userInfo = ["target": json]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }

        // Save to history
        if let target = target {
            DispatchQueue.main.async {
                self.historyManager.addNotification(title: title, body: body, target: target)
            }
        }
    }

    func sendNewCommitNotification(
        prNumber: Int,
        prTitle: String,
        repoFullName: String,
        authorLogin: String,
        commitMessage: String,
        playSound: Bool
    ) {
        let title = "\(repoFullName) #\(prNumber)"
        let shortMessage = String(commitMessage.prefix(80))
        let body = "📦 \(authorLogin): \(shortMessage)"

        let target = NotificationTarget(
            prNumber: prNumber,
            repoFullName: repoFullName,
            filePath: nil,
            line: nil,
            commentId: nil
        )

        sendNotification(title: title, body: body, playSound: playSound, target: target)
    }

    func sendNewCommentNotification(
        prNumber: Int,
        prTitle: String,
        repoFullName: String,
        authorLogin: String,
        commentBody: String,
        filePath: String?,
        line: Int?,
        commentId: Int,
        playSound: Bool
    ) {
        let title = "\(repoFullName) #\(prNumber)"
        let shortBody = String(commentBody.prefix(80))
        let body = "💬 \(authorLogin): \(shortBody)"

        let target = NotificationTarget(
            prNumber: prNumber,
            repoFullName: repoFullName,
            filePath: filePath,
            line: line,
            commentId: commentId
        )

        sendNotification(title: title, body: body, playSound: playSound, target: target)
    }

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Handle notification tap when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let targetJson = userInfo["target"] as? String,
           let data = targetJson.data(using: .utf8),
           let target = try? JSONDecoder().decode(NotificationTarget.self, from: data) {
            DispatchQueue.main.async {
                self.onNotificationTapped?(target)
            }
        }

        completionHandler()
    }
}

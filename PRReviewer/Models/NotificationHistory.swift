import Foundation

struct NotificationHistoryItem: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let timestamp: Date
    let target: NotificationTarget
    var isRead: Bool

    init(title: String, body: String, target: NotificationTarget) {
        self.id = UUID().uuidString
        self.title = title
        self.body = body
        self.timestamp = Date()
        self.target = target
        self.isRead = false
    }
}

class NotificationHistoryManager: ObservableObject {
    static let shared = NotificationHistoryManager()

    private let storageKey = "notification_history"
    private let maxItems = 100

    @Published var items: [NotificationHistoryItem] = []

    private init() {
        loadHistory()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([NotificationHistoryItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    private func saveHistory() {
        // Keep only the most recent items
        let trimmed = Array(items.prefix(maxItems))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func addNotification(title: String, body: String, target: NotificationTarget) {
        let item = NotificationHistoryItem(title: title, body: body, target: target)
        items.insert(item, at: 0)  // Add to beginning (newest first)
        saveHistory()
    }

    func markAsRead(_ item: NotificationHistoryItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isRead = true
            saveHistory()
        }
    }

    func markAllAsRead() {
        for i in items.indices {
            items[i].isRead = true
        }
        saveHistory()
    }

    func clearHistory() {
        items = []
        saveHistory()
    }

    var unreadCount: Int {
        items.filter { !$0.isRead }.count
    }
}

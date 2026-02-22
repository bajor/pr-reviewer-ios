import Foundation

struct GitHubAccount: Codable, Identifiable, Equatable {
    let id: String  // UUID
    let username: String
    var isActive: Bool

    init(username: String) {
        self.id = UUID().uuidString
        self.username = username
        self.isActive = true
    }
}

class AccountManager: ObservableObject {
    static let shared = AccountManager()
    static let maxAccounts = 5

    private let accountsKey = "github_accounts"
    private let soundEnabledKey = "notification_sound_enabled"
    private let blockedUsernamesKey = "blocked_usernames"

    @Published var accounts: [GitHubAccount] = []
    @Published var soundEnabled: Bool = true
    @Published var blockedUsernames: [String] = []

    private init() {
        loadAccounts()
        loadBlockedUsernames()
        soundEnabled = UserDefaults.standard.object(forKey: soundEnabledKey) as? Bool ?? true
    }

    var canAddMoreAccounts: Bool {
        accounts.count < Self.maxAccounts
    }

    private func loadAccounts() {
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              let decoded = try? JSONDecoder().decode([GitHubAccount].self, from: data) else {
            accounts = []
            return
        }
        accounts = decoded
    }

    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }

    func addAccount(username: String, token: String) throws {
        // Check if account already exists
        if accounts.contains(where: { $0.username.lowercased() == username.lowercased() }) {
            // Update existing
            if let index = accounts.firstIndex(where: { $0.username.lowercased() == username.lowercased() }) {
                try KeychainManager.saveToken(token, for: accounts[index].id)
            }
            return
        }

        let account = GitHubAccount(username: username)
        try KeychainManager.saveToken(token, for: account.id)
        accounts.append(account)
        saveAccounts()
    }

    func removeAccount(_ account: GitHubAccount) {
        try? KeychainManager.deleteToken(for: account.id)
        accounts.removeAll { $0.id == account.id }
        saveAccounts()
    }

    func toggleAccount(_ account: GitHubAccount) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index].isActive.toggle()
            saveAccounts()
        }
    }

    var activeAccounts: [GitHubAccount] {
        accounts.filter { $0.isActive }
    }

    var hasValidCredentials: Bool {
        !activeAccounts.isEmpty && activeAccounts.allSatisfy { KeychainManager.hasToken(for: $0.id) }
    }

    func setSoundEnabled(_ enabled: Bool) {
        soundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: soundEnabledKey)
    }

    func clearAll() {
        for account in accounts {
            try? KeychainManager.deleteToken(for: account.id)
        }
        accounts = []
        saveAccounts()
        soundEnabled = true
        UserDefaults.standard.set(true, forKey: soundEnabledKey)
        blockedUsernames = []
        saveBlockedUsernames()
    }

    // MARK: - Blocked Users

    private func loadBlockedUsernames() {
        guard let data = UserDefaults.standard.data(forKey: blockedUsernamesKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            blockedUsernames = []
            return
        }
        blockedUsernames = decoded
    }

    private func saveBlockedUsernames() {
        if let data = try? JSONEncoder().encode(blockedUsernames) {
            UserDefaults.standard.set(data, forKey: blockedUsernamesKey)
            UserDefaults.standard.synchronize()
        }
    }

    func addBlockedUser(_ username: String) {
        let normalized = username.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty, !blockedUsernames.contains(normalized) else { return }
        blockedUsernames.append(normalized)
        saveBlockedUsernames()
    }

    func removeBlockedUser(_ username: String) {
        blockedUsernames.removeAll { $0 == username.lowercased() }
        saveBlockedUsernames()
    }

    func isUserBlocked(_ username: String) -> Bool {
        blockedUsernames.contains(username.lowercased())
    }
}

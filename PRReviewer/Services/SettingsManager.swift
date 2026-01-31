import Foundation

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let usernameKey = "github_username"
    private let soundEnabledKey = "notification_sound_enabled"

    @Published var username: String {
        didSet {
            UserDefaults.standard.set(username, forKey: usernameKey)
        }
    }

    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: soundEnabledKey)
        }
    }

    private init() {
        self.username = UserDefaults.standard.string(forKey: usernameKey) ?? ""
        self.soundEnabled = UserDefaults.standard.object(forKey: soundEnabledKey) as? Bool ?? true
    }

    func saveSettings(username: String, token: String, soundEnabled: Bool) throws {
        self.username = username
        self.soundEnabled = soundEnabled
        try KeychainManager.saveLegacyToken(token)
    }

    func clearAll() {
        username = ""
        soundEnabled = true
        try? KeychainManager.deleteLegacyToken()
        PRStateCache.clearAll()
    }

    var hasValidCredentials: Bool {
        !username.isEmpty && KeychainManager.getLegacyToken() != nil
    }
}

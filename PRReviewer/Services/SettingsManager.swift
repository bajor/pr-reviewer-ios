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

}

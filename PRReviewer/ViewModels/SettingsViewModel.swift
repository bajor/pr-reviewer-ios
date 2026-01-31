import Foundation
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var username = ""
    @Published var token = ""
    @Published var soundEnabled = true
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var showSuccess = false

    private let settings = SettingsManager.shared

    init() {
        soundEnabled = settings.soundEnabled
    }

    func saveSettings() {
        guard !username.isEmpty else {
            errorMessage = "Username is required"
            return
        }

        guard !token.isEmpty else {
            errorMessage = "Token is required"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            try settings.saveSettings(
                username: username,
                token: token,
                soundEnabled: soundEnabled
            )

            username = ""
            token = ""

            showSuccess = true
            isSaving = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showSuccess = false
            }

        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    func clearAllSettings() {
        settings.clearAll()
        username = ""
        token = ""
        soundEnabled = true
    }

    var hasExistingCredentials: Bool {
        settings.hasValidCredentials
    }
}

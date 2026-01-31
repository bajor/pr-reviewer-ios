import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case encodingError

    var errorDescription: String? {
        switch self {
        case .duplicateItem: return "Item already exists in keychain"
        case .itemNotFound: return "Item not found in keychain"
        case .unexpectedStatus(let status): return "Keychain error: \(status)"
        case .encodingError: return "Failed to encode data"
        }
    }
}

struct KeychainManager {
    private static let service = "com.prreviewer.github"

    // MARK: - Multi-account support

    static func saveToken(_ token: String, for accountId: String) throws {
        try? deleteToken(for: accountId)

        guard let data = token.data(using: .utf8) else {
            throw KeychainError.encodingError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountId,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func getToken(for accountId: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    static func deleteToken(for accountId: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountId
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func hasToken(for accountId: String) -> Bool {
        getToken(for: accountId) != nil
    }

    // MARK: - Legacy single-token support (for migration)

    private static let legacyTokenAccount = "github_token"

    static func getLegacyToken() -> String? {
        getToken(for: legacyTokenAccount)
    }

    static func saveLegacyToken(_ token: String) throws {
        try saveToken(token, for: legacyTokenAccount)
    }

    static func deleteLegacyToken() throws {
        try deleteToken(for: legacyTokenAccount)
    }
}

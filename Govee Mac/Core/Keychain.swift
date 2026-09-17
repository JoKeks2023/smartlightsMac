import Foundation
import Security

// MARK: - Keychain Helper

enum KeychainSecretStore {
    static func save(service: String, account: String, value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Keychain save failed: \(status)"])
        }
    }

    static func load(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Keychain load failed: \(status)"])
        }
        return String(data: data, encoding: .utf8)
    }
}

enum APIKeyKeychain {
    private static let service = "com.govee.mac.api"
    private static let account = "goveeApiKey"

    static func save(key: String) throws {
        try KeychainSecretStore.save(service: service, account: account, value: key)
    }

    static func load() throws -> String? {
        try KeychainSecretStore.load(service: service, account: account)
    }
}

enum HomeAssistantTokenKeychain {
    private static let service = "com.govee.mac.homeassistant"
    private static let account = "haToken"

    static func save(token: String) throws {
        try KeychainSecretStore.save(service: service, account: account, value: token)
    }

    static func load() throws -> String? {
        try KeychainSecretStore.load(service: service, account: account)
    }
}

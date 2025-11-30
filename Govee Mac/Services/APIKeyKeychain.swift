import Foundation
import Security

/// A small Keychain helper for securely storing and retrieving the Govee API key.
/// Usage:
///   try APIKeyKeychain.save(key: "YOUR_KEY")
///   let key = try APIKeyKeychain.load()
///   try APIKeyKeychain.delete()
struct APIKeyKeychain {
    // Adjust service to match your bundle identifier for uniqueness.
    private static let service = "com.govee.mac.api"
    private static let account = "goveeApiKey"

    enum KeychainError: Error, CustomStringConvertible {
        case itemNotFound
        case unexpectedStatus(OSStatus)
        case dataConversionFailed

        var description: String {
            switch self {
            case .itemNotFound: return "Keychain item not found"
            case .unexpectedStatus(let status): return "Keychain unexpected status: \(status)"
            case .dataConversionFailed: return "Failed to convert keychain data to String"
            }
        }
    }

    /// Save (or replace) the API key in the Keychain.
    /// Passing an empty string will delete any existing stored key.
    static func save(key: String) throws {
        // If empty we treat as delete request.
        guard !key.isEmpty else {
            try delete()
            return
        }
        let encoded = Data(key.utf8)

        // Remove existing if present to simplify logic.
        try? delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: encoded,
            // Accessible after first unlock for background accessibility; adjust if stricter policy desired.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    /// Load the API key, returning nil if none exists.
    static func load() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return string
    }

    /// Delete any stored API key (idempotent).
    static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound { throw KeychainError.unexpectedStatus(status) }
    }
}

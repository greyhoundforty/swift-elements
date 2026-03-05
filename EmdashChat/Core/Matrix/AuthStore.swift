import Foundation
import Security

/// Persists Matrix session credentials in the system Keychain.
final class AuthStore {
    private let service = "com.ryan.emdashchat"
    private let account = "matrix-session"

    func save(session: MatrixSession) throws {
        let data = try JSONEncoder().encode(session)
        // Delete any existing item first
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainWriteFailed(status)
        }
    }

    func load() -> MatrixSession? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(MatrixSession.self, from: data)
    }

    func clear() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Session model

struct MatrixSession: Codable {
    let accessToken: String
    let userId: String
    let homeserver: String
    var refreshToken: String?
    var deviceId: String?
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case keychainWriteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychainWriteFailed(let status):
            return "Keychain write failed (OSStatus \(status))"
        }
    }
}

import Foundation
import Security
import MatrixRustSDK

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

    func load() throws -> MatrixSession? {
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

// MARK: - ClientSessionDelegate

extension AuthStore: ClientSessionDelegate {
    func retrieveSessionFromKeychain(userId: String) throws -> Session {
        guard let s = try load() else { throw AuthError.noSession }
        return s.toSDKSession()
    }

    func saveSessionInKeychain(session: Session) {
        try? save(session: MatrixSession(from: session))
    }
}

// MARK: - Session model

struct MatrixSession: Codable {
    let accessToken: String
    let userId: String
    let homeserver: String
    var refreshToken: String?
    var deviceId: String?
    /// Non-nil when the server uses a Sliding Sync proxy; nil means native sliding sync.
    var slidingSyncProxyUrl: String?
    /// OIDC data blob from the SDK, preserved for session restore.
    var oidcData: String?
}

// MARK: - SDK mapping

extension MatrixSession {
    /// Create a MatrixSession from the SDK's Session type.
    init(from session: Session) {
        self.accessToken = session.accessToken
        self.userId = session.userId
        self.homeserver = session.homeserverUrl
        self.refreshToken = session.refreshToken
        self.deviceId = session.deviceId
        self.oidcData = session.oidcData
        if case .proxy(let url) = session.slidingSyncVersion {
            self.slidingSyncProxyUrl = url
        }
    }

    /// Convert back to the SDK's Session type for restoreSession.
    func toSDKSession() -> Session {
        let ssv: SlidingSyncVersion = slidingSyncProxyUrl.map { .proxy(url: $0) } ?? .native
        return Session(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: userId,
            deviceId: deviceId ?? "",
            homeserverUrl: homeserver,
            oidcData: oidcData,
            slidingSyncVersion: ssv
        )
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case keychainWriteFailed(OSStatus)
    case noSession

    var errorDescription: String? {
        switch self {
        case .keychainWriteFailed(let status):
            return "Keychain write failed (OSStatus \(status))"
        case .noSession:
            return "No stored session found"
        }
    }
}

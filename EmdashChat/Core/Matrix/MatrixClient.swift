import Foundation
import Observation

// TODO: MatrixRustSDK — when integrating the real SDK, uncomment:
// import MatrixRustSDK

// MARK: - MatrixClient
//
// Central hub for all Matrix state. An @Observable singleton consumed via
// SwiftUI .environment(matrixClient).
//
// SDK integration points are annotated with TODO: MatrixRustSDK.

@Observable
@MainActor
final class MatrixClient {
    static let shared = MatrixClient()

    // MARK: - Published state

    private(set) var rooms: [Room] = []
    private(set) var currentUser: MatrixUser?
    private(set) var session: MatrixSession?
    private(set) var isLoggedIn = false
    private(set) var loginError: String?

    // MARK: - Private

    private let authStore = AuthStore()
    private var syncManager: SyncManager?

    private init() {}

    // MARK: - Auth

    /// Authenticate with a homeserver using password credentials.
    func login(homeserver: String, username: String, password: String) async throws {
        loginError = nil

        // TODO: MatrixRustSDK integration:
        //   let client = try await ClientBuilder()
        //       .homeserverUrl(url: homeserver)
        //       .build()
        //   try await client.login(username: username, password: password, initialDeviceName: "EmdashChat", deviceId: nil)
        //   let session = try client.session()

        // Stub: simulate network delay
        try await Task.sleep(for: .milliseconds(800))

        let userId = "@\(username.hasPrefix("@") ? String(username.dropFirst()).components(separatedBy: ":").first ?? username : username):\(URL(string: homeserver)?.host ?? "matrix.org")"

        let newSession = MatrixSession(
            accessToken: "mock_token_\(UUID().uuidString)",
            userId: userId,
            homeserver: homeserver,
            deviceId: "EMDASH_\(Int.random(in: 1000...9999))"
        )

        try authStore.save(session: newSession)
        applySession(newSession)
        await startSync()
    }

    /// Restore a previous session from Keychain on app launch.
    func restoreSession() async {
        guard let saved = authStore.load() else { return }
        // TODO: MatrixRustSDK — restore session from stored credentials:
        //   let client = try await ClientBuilder().homeserverUrl(url: saved.homeserver).build()
        //   try await client.restoreSession(session: saved)
        applySession(saved)
        await startSync()
    }

    func logout() async {
        await syncManager?.stop()
        syncManager = nil
        authStore.clear()
        rooms = []
        currentUser = nil
        session = nil
        isLoggedIn = false
    }

    // MARK: - Room list updates (called by SyncManager)

    func updateRooms(_ updated: [Room]) {
        rooms = updated
    }

    // MARK: - Private helpers

    private func applySession(_ s: MatrixSession) {
        session = s
        currentUser = MatrixUser(
            id: s.userId,
            displayName: s.userId.localpart
        )
        isLoggedIn = true
    }

    private func startSync() async {
        let manager = SyncManager(client: self)
        syncManager = manager
        await manager.start()
    }
}

// MARK: - String helpers

private extension String {
    /// Extract the local part from a Matrix ID (@user:server → "user")
    var localpart: String {
        hasPrefix("@") ? String(dropFirst().prefix(while: { $0 != ":" })) : self
    }
}

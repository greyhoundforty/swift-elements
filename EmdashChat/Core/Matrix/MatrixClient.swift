import Foundation
import Observation
import os
import MatrixRustSDK

private let log = Logger(subsystem: "com.ryan.emdashchat", category: "MatrixClient")

// MARK: - MatrixClient
//
// Central hub for all Matrix state. An @Observable singleton consumed via
// SwiftUI .environment(matrixClient).

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
    private(set) var syncState: String = "idle"
    private(set) var debugLog: [String] = []

    func appendDebug(_ line: String) {
        let ts = DateFormatter.localizedString(from: .now, dateStyle: .none, timeStyle: .medium)
        debugLog.append("[\(ts)] \(line)")
        if debugLog.count > 150 { debugLog.removeFirst() }
    }

    func clearDebugLog() {
        debugLog = []
    }

    // MARK: - Private

    private let authStore = AuthStore()
    private var syncManager: SyncManager?
    // Retained for media uploads and direct room access (polling fallback)
    private(set) var sdkClient: Client?
    // Populated by SyncManager when sliding sync is unavailable
    private(set) var sdkRooms: [String: MatrixRustSDK.Room] = [:]

    private init() {}

    // MARK: - Auth

    /// Authenticate with a homeserver using password credentials.
    func login(homeserver: String, username: String, password: String) async throws {
        loginError = nil
        log.info("login: building client for \(homeserver, privacy: .public)")

        let client = try await ClientBuilder()
            .homeserverUrl(url: homeserver)
            .setSessionDelegate(sessionDelegate: authStore)
            .sessionPaths(dataPath: sdkDataPath(), cachePath: sdkCachePath())
            .slidingSyncVersionBuilder(versionBuilder: .discoverNative)
            .build()

        let availableSSV = await client.availableSlidingSyncVersions()
        let resolvedSSV = client.slidingSyncVersion()
        func ssvDesc(_ v: SlidingSyncVersion) -> String {
            switch v { case .none: return "none"; case .native: return "native"; case .proxy(let u): return "proxy(\(u))" }
        }
        log.info("login: availableSSV=[\(availableSSV.map(ssvDesc).joined(separator: ","), privacy: .public)] resolved=\(ssvDesc(resolvedSSV), privacy: .public)")
        log.info("login: client built, attempting password auth for \(username, privacy: .public)")
        // login() is directly on Client — no .matrixAuth() wrapper
        do {
            try await client.login(
                username: username,
                password: password,
                initialDeviceName: "EmdashChat macOS",
                deviceId: nil
            )
        } catch {
            // If the crypto store has data from a previous (e.g. stub) session,
            // the SDK rejects the new login. Wipe the store and retry once.
            if "\(error)".contains("account in the store doesn") {
                log.warning("login: crypto store mismatch — wiping store and retrying")
                wipeSdkStore()
                let freshClient = try await ClientBuilder()
                    .homeserverUrl(url: homeserver)
                    .setSessionDelegate(sessionDelegate: authStore)
                    .sessionPaths(dataPath: sdkDataPath(), cachePath: sdkCachePath())
                    .slidingSyncVersionBuilder(versionBuilder: .discoverNative)
                    .build()
                try await freshClient.login(
                    username: username,
                    password: password,
                    initialDeviceName: "EmdashChat macOS",
                    deviceId: nil
                )
                self.sdkClient = freshClient
                let newSession = MatrixSession(from: try freshClient.session())
                try authStore.save(session: newSession)
                applySession(newSession)
                log.info("login: retry succeeded for userId=\(newSession.userId, privacy: .public)")
                await startSync(sdkClient: freshClient)
                log.info("login: complete (after store wipe)")
                return
            }
            throw error
        }

        log.info("login: auth succeeded, storing session")
        self.sdkClient = client
        let newSession = MatrixSession(from: try client.session())
        try authStore.save(session: newSession)
        applySession(newSession)
        log.info("login: starting sync for userId=\(newSession.userId, privacy: .public)")
        await startSync(sdkClient: client)
        log.info("login: complete")
    }

    /// Restore a previous session from Keychain on app launch.
    func restoreSession() async throws {
        log.info("restoreSession: checking keychain")
        guard let stored = try authStore.load() else {
            log.info("restoreSession: no stored session found")
            return
        }
        log.info("restoreSession: found session for \(stored.userId, privacy: .public)")

        let client = try await ClientBuilder()
            .homeserverUrl(url: stored.homeserver)
            .setSessionDelegate(sessionDelegate: authStore)
            .sessionPaths(dataPath: sdkDataPath(), cachePath: sdkCachePath())
            .slidingSyncVersionBuilder(versionBuilder: .discoverNative)
            .build()

        log.info("restoreSession: client built, restoring session")
        try await client.restoreSession(session: stored.toSDKSession())

        self.sdkClient = client
        applySession(stored)
        log.info("restoreSession: session restored, starting sync")
        await startSync(sdkClient: client)
        log.info("restoreSession: complete")
    }

    func logout() async {
        await syncManager?.stop()
        syncManager = nil
        sdkClient = nil
        authStore.clear()
        rooms = []
        currentUser = nil
        session = nil
        isLoggedIn = false
    }

    // MARK: - Room list updates (called by SyncManager)

    func updateRooms(_ updated: [Room]) {
        rooms = updated
        appendDebug("rooms updated: \(updated.count) room(s)")
    }

    func updateSyncState(_ state: String) {
        syncState = state
        appendDebug("syncService → \(state)")
    }

    func updateSdkRooms(_ updated: [String: MatrixRustSDK.Room]) {
        sdkRooms = updated
    }

    // MARK: - Room access (used by ChatViewModel)

    /// Returns the RoomListItem for a given room ID via the active SyncService (sliding sync path).
    func roomListItem(for roomId: String) -> RoomListItem? {
        guard let service = syncManager?.syncService else { return nil }
        return try? service.roomListService().room(roomId: roomId)
    }

    /// Returns the SDK Room directly — populated by the polling fallback path.
    func sdkRoom(for roomId: String) -> MatrixRustSDK.Room? {
        sdkRooms[roomId]
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

    private func startSync(sdkClient: Client) async {
        let manager = SyncManager(matrixClient: self)
        syncManager = manager
        await manager.start(client: sdkClient)
    }

    private func wipeSdkStore() {
        let paths = [sdkDataPath(), sdkCachePath()]
        for path in paths {
            try? FileManager.default.removeItem(atPath: path)
        }
        authStore.clear()
        log.info("wipeSdkStore: cleared sdk data, cache, and keychain")
    }

    private func sdkDataPath() -> String {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EmdashChat/sdk/data", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.path
    }

    private func sdkCachePath() -> String {
        let base = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EmdashChat/sdk", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.path
    }
}

// MARK: - String helpers

private extension String {
    /// Extract the local part from a Matrix ID (@user:server → "user")
    var localpart: String {
        hasPrefix("@") ? String(dropFirst().prefix(while: { $0 != ":" })) : self
    }
}

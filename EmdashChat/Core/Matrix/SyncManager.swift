import Foundation
import os
import MatrixRustSDK

private let log = Logger(subsystem: "com.ryan.emdashchat", category: "SyncManager")

// MARK: - SyncManager

@MainActor
final class SyncManager {
    private weak var matrixClient: MatrixClient?

    private(set) var syncService: SyncService?
    private var roomList: RoomList?
    private var roomListEntriesResult: RoomListEntriesWithDynamicAdaptersResult?
    private var roomListController: RoomListDynamicEntriesController?
    private var roomListEntriesStreamHandle: TaskHandle?
    private var syncTask: Task<Void, Never>?
    private var syncStateHandle: TaskHandle?
    private var loadingStateResult: RoomListLoadingStateResult?

    init(matrixClient: MatrixClient) {
        self.matrixClient = matrixClient
    }

    func start(client: Client) async {
        let ssv = client.slidingSyncVersion()
        let ssvDesc: String
        switch ssv {
        case .none:             ssvDesc = "none"
        case .native:           ssvDesc = "native"
        case .proxy(let url):   ssvDesc = "proxy(\(url))"
        }
        log.info("start: slidingSyncVersion=\(ssvDesc, privacy: .public)")

        do {
            let svc = try await client.syncService().finish()
            syncService = svc
            log.info("start: sync service built, fetching room list")

            let list = try await svc.roomListService().allRooms()
            roomList = list
            log.info("start: room list obtained, subscribing to updates")

            roomListEntriesResult = list.entriesWithDynamicAdapters(pageSize: 50, listener: self)
            roomListController = roomListEntriesResult?.controller()
            roomListEntriesStreamHandle = roomListEntriesResult?.entriesStream()
            loadingStateResult = try? list.loadingState(listener: self)
            log.info("start: initial loadingState=\(self.loadingStateDesc(self.loadingStateResult?.state), privacy: .public)")
            syncStateHandle = svc.state(listener: self)

            // Trigger the first page of rooms from the dynamic adapter.
            roomListController?.addOnePage()
            log.info("start: addOnePage called")

            syncTask = Task { [weak self] in
                log.info("start: sync loop running")
                await svc.start()
                log.info("start: sync loop exited")
                _ = self
            }
        } catch {
            log.error("start: SyncService unavailable (\(error, privacy: .public)) — falling back to direct room polling")
            startPollingFallback(client: client)
        }
    }

    // MARK: - Polling fallback (servers without sliding sync)

    private func startPollingFallback(client: Client) {
        log.info("polling: starting direct room poll every 30s")
        syncTask = Task { [weak self] in
            while !Task.isCancelled {
                let sdkRooms = client.rooms()
                log.info("polling: \(sdkRooms.count, privacy: .public) room(s)")
                await MainActor.run { [weak self] in
                    guard let self, let mc = self.matrixClient else { return }
                    mc.updateRooms(sdkRooms.map { Room(sdkRoom: $0) })
                    mc.updateSdkRooms(Dictionary(uniqueKeysWithValues: sdkRooms.map { ($0.id(), $0) }))
                }
                do { try await Task.sleep(for: .seconds(30)) } catch { break }
            }
        }
    }

    func stop() async {
        syncTask?.cancel()
        syncStateHandle?.cancel()
        syncStateHandle = nil
        roomListEntriesStreamHandle?.cancel()
        roomListEntriesStreamHandle = nil
        loadingStateResult = nil
        roomListController = nil
        roomListEntriesResult = nil
        roomList = nil
        try? await syncService?.stop()
        syncService = nil
        syncTask = nil
    }

    private func loadingStateDesc(_ state: RoomListLoadingState?) -> String {
        switch state {
        case .none:                               return "nil"
        case .notLoaded:                          return "notLoaded"
        case .loaded(let n): return "loaded(max=\(n.map { "\($0)" } ?? "nil"))"
        }
    }

    // MARK: - Room list diff application (sliding sync path)

    private func applyDiff(_ diffs: [RoomListEntriesUpdate]) {
        guard let matrixClient else { return }
        log.info("applyDiff: \(diffs.count, privacy: .public) update(s)")
        var rooms = matrixClient.rooms

        for diff in diffs {
            switch diff {
            case .append(let items):
                rooms.append(contentsOf: items.map(Room.init(roomListItem:)))
            case .pushBack(let item):
                rooms.append(Room(roomListItem: item))
            case .pushFront(let item):
                rooms.insert(Room(roomListItem: item), at: 0)
            case .set(let index, let item):
                let i = Int(index)
                if rooms.indices.contains(i) { rooms[i] = Room(roomListItem: item) }
            case .remove(let index):
                let i = Int(index)
                if rooms.indices.contains(i) { rooms.remove(at: i) }
            case .reset(let items):
                rooms = items.map(Room.init(roomListItem:))
            case .insert(let index, let item):
                rooms.insert(Room(roomListItem: item), at: min(Int(index), rooms.count))
            case .clear:
                rooms = []
            case .popBack:
                if !rooms.isEmpty { rooms.removeLast() }
            case .popFront:
                if !rooms.isEmpty { rooms.removeFirst() }
            case .truncate(let length):
                rooms = Array(rooms.prefix(Int(length)))
            }
        }

        log.info("applyDiff: room count=\(rooms.count, privacy: .public)")
        matrixClient.updateRooms(rooms)
    }
}

// MARK: - RoomListLoadingStateListener

extension SyncManager: RoomListLoadingStateListener {
    nonisolated func onUpdate(state: RoomListLoadingState) {
        let desc: String
        switch state {
        case .notLoaded:     desc = "notLoaded"
        case .loaded(let n): desc = "loaded(max=\(n.map { "\($0)" } ?? "nil"))"
        }
        log.info("roomList loadingState → \(desc, privacy: .public)")
        Task { @MainActor [weak self] in
            self?.matrixClient?.appendDebug("loadingState → \(desc)")
        }
    }
}

// MARK: - SyncServiceStateObserver

extension SyncManager: SyncServiceStateObserver {
    nonisolated func onUpdate(state: SyncServiceState) {
        let desc: String
        switch state {
        case .idle:        desc = "idle"
        case .running:     desc = "running"
        case .terminated:  desc = "terminated"
        case .error:       desc = "error"
        }
        log.info("syncService state → \(desc, privacy: .public)")
        Task { @MainActor [weak self] in
            self?.matrixClient?.updateSyncState(desc)
        }
    }
}

// MARK: - RoomListEntriesListener

extension SyncManager: RoomListEntriesListener {
    nonisolated func onUpdate(roomEntriesUpdate: [RoomListEntriesUpdate]) {
        log.info("roomList onUpdate: \(roomEntriesUpdate.count, privacy: .public) update(s)")
        Task { @MainActor [weak self] in
            self?.matrixClient?.appendDebug("roomList: \(roomEntriesUpdate.count) diff(s)")
            self?.applyDiff(roomEntriesUpdate)
        }
    }
}

// MARK: - Room mapping

extension Room {
    /// From a sliding-sync RoomListItem.
    init(roomListItem item: RoomListItem) {
        self.init(
            id: item.id(),
            name: item.displayName() ?? item.id(),
            isDM: item.isDirect()
        )
    }

    /// From a direct SDK Room (polling fallback path).
    init(sdkRoom room: MatrixRustSDK.Room) {
        self.init(
            id: room.id(),
            name: room.displayName() ?? room.id(),
            topic: room.topic(),
            isDM: room.isDirect()
        )
    }
}

// MARK: - Mock fallback (offline / simulator)

extension SyncManager {
    static func mockMessages(for roomId: String, currentUserId: String) -> [Message] {
        let alice = MatrixUser(id: "@alice:matrix.org", displayName: "Alice")
        let me    = MatrixUser(id: currentUserId, displayName: "Me")
        guard roomId == "!dm-alice:matrix.org" else { return [] }
        return [
            Message(id: "$m1", roomId: roomId, sender: alice,
                    content: .text("Hey! Have you tried the new EmdashChat build?"),
                    timestamp: .now - 900),
            Message(id: "$m2", roomId: roomId, sender: me,
                    content: .text("Just fired it up — looks great so far!"),
                    timestamp: .now - 840, isFromCurrentUser: true),
        ]
    }

    static let simulatedUsers = [
        MatrixUser(id: "@alice:matrix.org", displayName: "Alice"),
        MatrixUser(id: "@bob:matrix.org", displayName: "Bob"),
    ]

    static let simulatedLines = [
        "That's a great point!", "Totally agree", "Interesting, tell me more",
        "Good to know!", "Makes sense to me",
    ]
}

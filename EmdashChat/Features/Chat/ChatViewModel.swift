import Foundation
import Observation
import os
import MatrixRustSDK

private let log = Logger(subsystem: "com.ryan.emdashchat", category: "ChatViewModel")

@Observable
@MainActor
final class ChatViewModel {
    let roomId: String

    private(set) var messages: [Message] = []
    private(set) var room: Room?
    private(set) var isLoadingHistory = false

    var composerText = ""
    var replyingTo: MessageReply?
    var isSimulating = false

    private var timelineTaskHandle: TaskHandle?
    private var simulationTask: Task<Void, Never>?

    init(roomId: String) {
        self.roomId = roomId
    }

    // MARK: - Lifecycle

    func onAppear(client: MatrixClient) async {
        room = client.rooms.first { $0.id == roomId }
        log.info("onAppear: roomId=\(self.roomId, privacy: .public) sdkClient=\(client.roomListItem(for: self.roomId) != nil ? "available" : "nil", privacy: .public)")

        // Resolve a Timeline via sliding sync (RoomListItem) or polling fallback (direct Room).
        let timeline: Timeline?
        if let item = client.roomListItem(for: roomId) {
            log.info("onAppear: using sliding sync path")
            do { try await item.initTimeline(eventTypeFilter: nil, internalIdPrefix: nil) } catch { log.error("onAppear: initTimeline failed: \(error, privacy: .public)") }
            timeline = try? await item.fullRoom().timeline()
        } else if let sdkRoom = client.sdkRoom(for: roomId) {
            log.info("onAppear: using polling fallback path")
            timeline = try? await sdkRoom.timeline()
        } else {
            log.warning("onAppear: no room source available — using mock data")
            messages = SyncManager.mockMessages(for: roomId, currentUserId: client.currentUser?.id ?? "")
            startSimulation()
            return
        }

        guard let timeline else {
            log.error("onAppear: timeline() failed for roomId=\(self.roomId, privacy: .public)")
            return
        }

        log.info("onAppear: subscribing to timeline diffs")
        timelineTaskHandle = await timeline.addListener(listener: self)

        log.info("onAppear: paginating backwards 50 events")
        _ = try? await timeline.paginateBackwards(numEvents: 50)
        log.info("onAppear: done, messages=\(self.messages.count, privacy: .public)")
    }

    func onDisappear() {
        timelineTaskHandle?.cancel()
        timelineTaskHandle = nil
        stopSimulation()
    }

    // MARK: - Reply

    func beginReply(to message: Message) {
        replyingTo = MessageReply(
            eventId: message.id,
            senderName: message.sender.displayName,
            preview: message.content.preview
        )
    }

    func cancelReply() {
        replyingTo = nil
    }

    // MARK: - Sending

    func send(client: MatrixClient) async {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let pendingReply = replyingTo

        composerText = ""
        replyingTo = nil

        let timeline: Timeline?
        if let item = client.roomListItem(for: roomId) {
            timeline = try? await item.fullRoom().timeline()
        } else {
            timeline = try? await client.sdkRoom(for: roomId)?.timeline()
        }

        guard let timeline else {
            // Optimistic local append when SDK unavailable
            let user = client.currentUser ?? MatrixUser(id: "@me:local", displayName: "Me")
            messages.append(Message(
                id: "$local_\(UUID().uuidString)",
                roomId: roomId,
                sender: user,
                content: .text(text),
                timestamp: .now,
                isFromCurrentUser: true,
                replyTo: pendingReply
            ))
            return
        }

        let content = messageEventContentFromMarkdown(md: text)
        _ = try? await timeline.send(msg: content)
    }

    // MARK: - GIF sending

    func sendGIF(_ gif: GIFResult, client: MatrixClient) async {
        let resolvedTimeline: Timeline?
        if let item = client.roomListItem(for: roomId) {
            resolvedTimeline = try? await item.fullRoom().timeline()
        } else {
            resolvedTimeline = try? await client.sdkRoom(for: roomId)?.timeline()
        }
        guard let sdkClient = client.sdkClient, let timeline = resolvedTimeline else {
            // Optimistic local append when SDK unavailable
            let user = client.currentUser ?? MatrixUser(id: "@me:local", displayName: "Me")
            messages.append(Message(
                id: "$gif_\(UUID().uuidString)",
                roomId: roomId,
                sender: user,
                content: .image(gif.fullURL),
                timestamp: .now,
                isFromCurrentUser: true,
                replyTo: replyingTo
            ))
            replyingTo = nil
            return
        }

        replyingTo = nil

        do {
            let data = try Data(contentsOf: gif.fullURL)
            let mxcUri = try await sdkClient.uploadMedia(
                mimeType: "image/gif",
                data: data,
                progressWatcher: nil
            )
            let source = mediaSourceFromUrl(url: mxcUri)
            let imageContent = ImageMessageContent(
                body: "image.gif",
                formatted: nil,
                filename: "image.gif",
                source: source,
                info: nil
            )
            let content = try messageEventContentNew(msgtype: .image(content: imageContent))
            try await timeline.send(msg: content)
        } catch {
            log.error("sendGIF: upload/send failed: \(error, privacy: .public)")
        }
    }

    // MARK: - Pagination

    func loadOlderMessages() async {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        guard let item = MatrixClient.shared.roomListItem(for: roomId),
              let sdkRoom = try? item.fullRoom(),
              let timeline = try? await sdkRoom.timeline() else {
            do { try await Task.sleep(for: .milliseconds(600)) } catch {}
            return
        }

        _ = try? await timeline.paginateBackwards(numEvents: 50)
    }

    // MARK: - Multi-user simulation (offline/testing aid)

    func toggleSimulation() {
        if isSimulating { stopSimulation() } else { startSimulation() }
    }

    private func startSimulation() {
        guard !isSimulating else { return }
        isSimulating = true

        simulationTask = Task { [weak self] in
            while !Task.isCancelled {
                let delay = Double.random(in: 4...10)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { break }
                self?.addSimulatedMessage()
            }
        }
    }

    private func stopSimulation() {
        simulationTask?.cancel()
        simulationTask = nil
        isSimulating = false
    }

    private func addSimulatedMessage() {
        let user = SyncManager.simulatedUsers.randomElement()!
        let text = SyncManager.simulatedLines.randomElement()!

        var reply: MessageReply?
        if Double.random(in: 0...1) < 0.4, let target = messages.suffix(6).randomElement() {
            reply = MessageReply(
                eventId: target.id,
                senderName: target.sender.displayName,
                preview: target.content.preview
            )
        }

        messages.append(Message(
            id: "$sim_\(UUID().uuidString)",
            roomId: roomId,
            sender: user,
            content: .text(text),
            timestamp: .now,
            isFromCurrentUser: false,
            replyTo: reply
        ))
    }
}

// MARK: - TimelineListener

extension ChatViewModel: TimelineListener {
    // Called from a Rust background thread — dispatch to MainActor.
    nonisolated func onUpdate(diff: [TimelineDiff]) {
        Task { @MainActor [weak self] in
            self?.applyTimelineDiff(diff)
        }
    }
}

// MARK: - Timeline diff application

extension ChatViewModel {
    private func applyTimelineDiff(_ diffs: [TimelineDiff]) {
        for diff in diffs {
            switch diff.change() {
            case .append:
                if let items = diff.append() {
                    messages.append(contentsOf: items.compactMap { makeMessage(from: $0) })
                }
            case .pushBack:
                if let item = diff.pushBack(), let msg = makeMessage(from: item) {
                    messages.append(msg)
                }
            case .pushFront:
                if let item = diff.pushFront(), let msg = makeMessage(from: item) {
                    messages.insert(msg, at: 0)
                }
            case .set:
                if let update = diff.set() {
                    let idx = Int(update.index)
                    if let msg = makeMessage(from: update.item), messages.indices.contains(idx) {
                        messages[idx] = msg
                    }
                }
            case .remove:
                if let idx = diff.remove().map(Int.init), messages.indices.contains(idx) {
                    messages.remove(at: idx)
                }
            case .reset:
                messages = diff.reset()?.compactMap { makeMessage(from: $0) } ?? []
            case .insert:
                if let update = diff.insert() {
                    let idx = min(Int(update.index), messages.count)
                    if let msg = makeMessage(from: update.item) {
                        messages.insert(msg, at: idx)
                    }
                }
            case .clear:
                messages = []
            case .popBack:
                if !messages.isEmpty { messages.removeLast() }
            case .popFront:
                if !messages.isEmpty { messages.removeFirst() }
            case .truncate:
                if let length = diff.truncate() { messages = Array(messages.prefix(Int(length))) }
            }
        }
    }

    /// Maps an SDK TimelineItem to our Message model.
    /// Returns nil for non-event items (date separators, loading indicators, etc.)
    private func makeMessage(from item: TimelineItem) -> Message? {
        guard let event = item.asEvent(),
              let eventId = event.eventId() else { return nil }

        let senderId = event.sender()
        let sender = MatrixUser(
            id: senderId,
            displayName: senderId.localpart
        )
        let timestamp = Date(timeIntervalSince1970: TimeInterval(event.timestamp()) / 1000)
        let isOwn = event.isOwn()

        // content() returns TimelineItemContent; asMessage() extracts the SDK Message object.
        let itemContent = event.content()
        let messageContent: MessageContent

        switch itemContent.kind() {
        case .redactedMessage:
            messageContent = .redacted
        case .unableToDecrypt:
            // SDK decrypts before surfacing items; this is a fallback.
            messageContent = .unknown("Unable to decrypt")
        case .message:
            guard let sdkMsg = itemContent.asMessage() else {
                return nil
            }
            switch sdkMsg.msgtype() {
            case .text(let t):
                messageContent = .text(t.body)
            case .emote(let e):
                messageContent = .emote(e.body)
            case .image(let img):
                // MediaSource.url() returns non-optional String
                if let url = URL(string: img.source.url()) {
                    messageContent = .image(url)
                } else {
                    messageContent = .image(URL(string: "about:blank")!)
                }
            default:
                messageContent = .unknown(sdkMsg.body())
            }
        default:
            // State events, membership changes, etc. — skip.
            return nil
        }

        return Message(
            id: eventId,
            roomId: roomId,
            sender: sender,
            content: messageContent,
            timestamp: timestamp,
            isFromCurrentUser: isOwn
        )
    }
}

private extension String {
    var localpart: String {
        hasPrefix("@") ? String(dropFirst().prefix(while: { $0 != ":" })) : self
    }
}

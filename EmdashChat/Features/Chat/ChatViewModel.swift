import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    let roomId: String

    private(set) var messages: [Message] = []
    private(set) var room: Room?
    private(set) var isLoadingHistory = false

    var composerText = ""
    var replyingTo: MessageReply? = nil   // set when user invokes Reply on a message
    var isSimulating = false

    private var simulationTask: Task<Void, Never>?

    init(roomId: String) {
        self.roomId = roomId
    }

    // MARK: - Lifecycle

    func onAppear(client: MatrixClient) async {
        room = client.rooms.first { $0.id == roomId }

        // TODO: MatrixRustSDK — subscribe to room timeline:
        //   let timeline = try await sdkRoom.timeline()
        //   for await update in timeline.updates { ... }

        let userId = client.currentUser?.id ?? ""
        messages = SyncManager.mockMessages(for: roomId, currentUserId: userId)

        // Auto-start simulation for richer testing
        startSimulation()
    }

    func onDisappear() {
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

        let user = client.currentUser ?? MatrixUser(id: "@me:local", displayName: "Me")
        let message = Message(
            id: "$local_\(UUID().uuidString)",
            roomId: roomId,
            sender: user,
            content: .text(text),
            timestamp: .now,
            isFromCurrentUser: true,
            replyTo: pendingReply
        )
        messages.append(message)

        // TODO: MatrixRustSDK — send:
        //   try await sdkRoom.timeline().send(content: .text(text), replyToEventId: pendingReply?.eventId)
    }

    // MARK: - GIF sending

    func sendGIF(_ gif: GIFResult, client: MatrixClient) async {
        let user = client.currentUser ?? MatrixUser(id: "@me:local", displayName: "Me")
        let message = Message(
            id: "$gif_\(UUID().uuidString)",
            roomId: roomId,
            sender: user,
            content: .image(gif.fullURL),
            timestamp: .now,
            isFromCurrentUser: true,
            replyTo: replyingTo
        )
        replyingTo = nil
        messages.append(message)

        // TODO: MatrixRustSDK — upload GIF and send as m.image
    }

    // MARK: - Pagination

    func loadOlderMessages() async {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true
        try? await Task.sleep(for: .milliseconds(600))
        isLoadingHistory = false
    }

    // MARK: - Multi-user simulation

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
                await self?.addSimulatedMessage()
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

        // ~40% chance of replying to a recent message
        var reply: MessageReply? = nil
        if Double.random(in: 0...1) < 0.4, let target = messages.suffix(6).randomElement() {
            reply = MessageReply(
                eventId: target.id,
                senderName: target.sender.displayName,
                preview: target.content.preview
            )
        }

        let message = Message(
            id: "$sim_\(UUID().uuidString)",
            roomId: roomId,
            sender: user,
            content: .text(text),
            timestamp: .now,
            isFromCurrentUser: false,
            replyTo: reply
        )
        messages.append(message)
    }
}

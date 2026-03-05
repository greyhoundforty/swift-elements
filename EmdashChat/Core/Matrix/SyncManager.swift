import Foundation

// MARK: - SyncManager
//
// Manages the Matrix sync lifecycle. In production this wraps MatrixRustSDK's
// SlidingSync API. Currently uses mock data to enable UI development.
//
// Integration points marked with TODO: MatrixRustSDK

@MainActor
final class SyncManager {
    private weak var client: MatrixClient?
    private var syncTask: Task<Void, Never>?

    init(client: MatrixClient) {
        self.client = client
    }

    func start() async {
        // TODO: MatrixRustSDK — initialize ClientBuilder and SlidingSync
        // Example (requires real SDK):
        //   let sdkClient = try await ClientBuilder()
        //       .homeserverUrl(url: client.session?.homeserver ?? "")
        //       .build()
        //   let slidingSync = try await sdkClient.slidingSync(id: "main")
        //   ...

        // Populate with mock data for UI development
        populateMockRooms()

        // Background polling loop (replace with SDK event stream)
        syncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                // TODO: process sliding sync response from SDK
            }
        }
    }

    func stop() async {
        syncTask?.cancel()
        syncTask = nil
    }

    // MARK: - Mock data

    private func populateMockRooms() {
        let alice = MatrixUser(id: "@alice:matrix.org", displayName: "Alice")
        let bob = MatrixUser(id: "@bob:matrix.org", displayName: "Bob")

        let mockDM = Room(
            id: "!dm-alice:matrix.org",
            name: "Alice",
            unreadCount: 2,
            lastMessage: Message(
                id: "$evt1:matrix.org",
                roomId: "!dm-alice:matrix.org",
                sender: alice,
                content: .text("Hey, are you there?"),
                timestamp: Date().addingTimeInterval(-120)
            ),
            isDM: true,
            members: [alice]
        )

        let mockGeneral = Room(
            id: "!general:matrix.org",
            name: "General",
            unreadCount: 5,
            lastMessage: Message(
                id: "$evt2:matrix.org",
                roomId: "!general:matrix.org",
                sender: bob,
                content: .text("Welcome to EmdashChat!"),
                timestamp: Date().addingTimeInterval(-600)
            ),
            isDM: false,
            members: [alice, bob]
        )

        let mockRandom = Room(
            id: "!random:matrix.org",
            name: "Random",
            unreadCount: 0,
            isDM: false,
            members: [bob]
        )

        client?.updateRooms([mockDM, mockGeneral, mockRandom])
    }
}

// MARK: - Mock message timeline

extension SyncManager {
    /// Returns a rich mock timeline for a given room — replace with real SDK pagination.
    static func mockMessages(for roomId: String, currentUserId: String) -> [Message] {
        let alice   = MatrixUser(id: "@alice:matrix.org",   displayName: "Alice")
        let bob     = MatrixUser(id: "@bob:matrix.org",     displayName: "Bob")
        let charlie = MatrixUser(id: "@charlie:matrix.org", displayName: "Charlie")
        let me      = MatrixUser(id: currentUserId,         displayName: "Me")

        switch roomId {
        case "!dm-alice:matrix.org":
            return [
                Message(id: "$m1", roomId: roomId, sender: alice,
                        content: .text("Hey! Have you tried the new EmdashChat build?"),
                        timestamp: .now - 900),
                Message(id: "$m2", roomId: roomId, sender: me,
                        content: .text("Just fired it up — looks great so far 🎉"),
                        timestamp: .now - 840, isFromCurrentUser: true),
                Message(id: "$m3", roomId: roomId, sender: alice,
                        content: .text("Did the GIF picker work?"),
                        timestamp: .now - 800),
                Message(id: "$m4", roomId: roomId, sender: me,
                        content: .text("Yeah! Type /gif and it pops right up."),
                        timestamp: .now - 760, isFromCurrentUser: true,
                        replyTo: MessageReply(eventId: "$m3", senderName: "Alice",
                                              preview: "Did the GIF picker work?")),
                Message(id: "$m5", roomId: roomId, sender: alice,
                        content: .text("Nice. Are you testing the reply feature too?"),
                        timestamp: .now - 600),
                Message(id: "$m6", roomId: roomId, sender: alice,
                        content: .text("Right-click any message to try it 👆"),
                        timestamp: .now - 580),
                Message(id: "$m7", roomId: roomId, sender: me,
                        content: .text("Yep, doing that right now!"),
                        timestamp: .now - 200, isFromCurrentUser: true,
                        replyTo: MessageReply(eventId: "$m5", senderName: "Alice",
                                              preview: "Are you testing the reply feature too?")),
            ]

        case "!general:matrix.org":
            return [
                Message(id: "$g1", roomId: roomId, sender: alice,
                        content: .text("Welcome to #general everyone 👋"),
                        timestamp: .now - 7200),
                Message(id: "$g2", roomId: roomId, sender: bob,
                        content: .text("Thanks Alice! Glad to be here."),
                        timestamp: .now - 7100,
                        replyTo: MessageReply(eventId: "$g1", senderName: "Alice",
                                              preview: "Welcome to #general everyone 👋")),
                Message(id: "$g3", roomId: roomId, sender: charlie,
                        content: .text("Same here. This app already feels way better than Electron."),
                        timestamp: .now - 6800),
                Message(id: "$g4", roomId: roomId, sender: me,
                        content: .text("Ha, that was the whole point 😄"),
                        timestamp: .now - 6500, isFromCurrentUser: true),
                Message(id: "$g5", roomId: roomId, sender: bob,
                        content: .text("What's next on the roadmap?"),
                        timestamp: .now - 3600),
                Message(id: "$g6", roomId: roomId, sender: me,
                        content: .text("AT Protocol support is being researched right now actually!"),
                        timestamp: .now - 3400, isFromCurrentUser: true,
                        replyTo: MessageReply(eventId: "$g5", senderName: "Bob",
                                              preview: "What's next on the roadmap?")),
                Message(id: "$g7", roomId: roomId, sender: charlie,
                        content: .text("Bluesky integration would be 🔥"),
                        timestamp: .now - 3300,
                        replyTo: MessageReply(eventId: "$g6", senderName: "Me",
                                              preview: "AT Protocol support is being researched right now actually!")),
                Message(id: "$g8", roomId: roomId, sender: alice,
                        content: .text("Also loving the bubble color options in Settings"),
                        timestamp: .now - 600),
            ]

        case "!random:matrix.org":
            return [
                Message(id: "$r1", roomId: roomId, sender: bob,
                        content: .text("Anyone have good macOS app recommendations?"),
                        timestamp: .now - 1800),
                Message(id: "$r2", roomId: roomId, sender: charlie,
                        content: .text("EmdashChat obviously 😂"),
                        timestamp: .now - 1700,
                        replyTo: MessageReply(eventId: "$r1", senderName: "Bob",
                                              preview: "Anyone have good macOS app recommendations?")),
                Message(id: "$r3", roomId: roomId, sender: me,
                        content: .text("I walked right into that one"),
                        timestamp: .now - 1600, isFromCurrentUser: true),
            ]

        default:
            return []
        }
    }

    // MARK: - Simulated responses (for interactive testing)

    static let simulatedUsers = [
        MatrixUser(id: "@alice:matrix.org",   displayName: "Alice"),
        MatrixUser(id: "@bob:matrix.org",     displayName: "Bob"),
        MatrixUser(id: "@charlie:matrix.org", displayName: "Charlie"),
    ]

    static let simulatedLines = [
        "That's a great point!",
        "Totally agree 👍",
        "Interesting, tell me more",
        "LOL 😄",
        "I was thinking the same thing",
        "Can you elaborate on that?",
        "Good to know!",
        "Thanks for sharing",
        "Makes sense to me",
        "Wait, really? 👀",
        "On it!",
        "Has anyone else noticed that?",
        "That's wild",
        "Yep, same here",
        "Love that idea ✨",
    ]
}

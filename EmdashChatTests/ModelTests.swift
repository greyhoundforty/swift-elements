import Testing
import Foundation
@testable import EmdashChat

// MARK: - Room

@Suite("Room model")
struct RoomTests {
    @Test func idEquality() {
        let a = Room(id: "!abc:matrix.org", name: "General")
        let b = Room(id: "!abc:matrix.org", name: "Different name")
        #expect(a == b)
    }

    @Test func differentIdsNotEqual() {
        let a = Room(id: "!abc:matrix.org", name: "General")
        let b = Room(id: "!xyz:matrix.org", name: "General")
        #expect(a != b)
    }

    @Test func defaultsAreCorrect() {
        let room = Room(id: "!r:s.org", name: "Test")
        #expect(room.unreadCount == 0)
        #expect(room.isDM == false)
        #expect(room.members.isEmpty)
        #expect(room.topic == nil)
    }

    @Test func hashConsistency() {
        let room = Room(id: "!abc:matrix.org", name: "General")
        var set = Set<Room>()
        set.insert(room)
        set.insert(room)
        #expect(set.count == 1)
    }
}

// MARK: - Message grouping

@Suite("Message grouping")
struct MessageGroupingTests {
    private func makeUser(_ id: String) -> MatrixUser {
        MatrixUser(id: id, displayName: id, avatarURL: nil)
    }

    private func makeMessage(
        id: String = UUID().uuidString,
        sender: MatrixUser,
        at date: Date,
        content: MessageContent = .text("hi")
    ) -> Message {
        Message(id: id, roomId: "!r:s.org", sender: sender, content: content, timestamp: date)
    }

    @Test func sameUserWithinFiveMinutesGroups() {
        let user = makeUser("@alice:matrix.org")
        let now = Date()
        let first  = makeMessage(sender: user, at: now)
        let second = makeMessage(sender: user, at: now.addingTimeInterval(60))
        #expect(second.isGrouped(with: first))
    }

    @Test func sameUserAfterFiveMinutesDoesNotGroup() {
        let user = makeUser("@alice:matrix.org")
        let now = Date()
        let first  = makeMessage(sender: user, at: now)
        let second = makeMessage(sender: user, at: now.addingTimeInterval(301))
        #expect(!second.isGrouped(with: first))
    }

    @Test func differentUsersDoNotGroup() {
        let alice = makeUser("@alice:matrix.org")
        let bob   = makeUser("@bob:matrix.org")
        let now = Date()
        let first  = makeMessage(sender: alice, at: now)
        let second = makeMessage(sender: bob,   at: now.addingTimeInterval(10))
        #expect(!second.isGrouped(with: first))
    }

    @Test func replyBreaksGrouping() {
        let user = makeUser("@alice:matrix.org")
        let now = Date()
        let first = makeMessage(sender: user, at: now)
        var second = makeMessage(sender: user, at: now.addingTimeInterval(10))
        second = Message(
            id: second.id,
            roomId: second.roomId,
            sender: second.sender,
            content: second.content,
            timestamp: second.timestamp,
            replyTo: MessageReply(eventId: "$ev1:s.org", senderName: "Alice", preview: "hi")
        )
        #expect(!second.isGrouped(with: first))
    }

    @Test func nilPreviousNeverGroups() {
        let user = makeUser("@alice:matrix.org")
        let msg = makeMessage(sender: user, at: Date())
        #expect(!msg.isGrouped(with: nil))
    }
}

// MARK: - MessageContent preview

@Suite("MessageContent.preview")
struct MessageContentPreviewTests {
    @Test func textPreview()    { #expect(MessageContent.text("hello").preview == "hello") }
    @Test func emotePreview()   { #expect(MessageContent.emote("waves").preview == "* waves") }
    @Test func imagePreview()   { #expect(MessageContent.image(URL(string: "https://example.com/a.gif")!).preview == "📷 Image") }
    @Test func redactedPreview(){ #expect(MessageContent.redacted.preview == "Message deleted") }
    @Test func unknownPreview() { #expect(MessageContent.unknown("m.sticker").preview == "") }
}

import Foundation

struct Room: Identifiable, Hashable {
    let id: String          // Matrix room ID: !xxx:server.org
    var name: String
    var topic: String?
    var avatarURL: URL?
    var unreadCount: Int = 0
    var lastMessage: Message?
    var isDM: Bool = false
    var members: [MatrixUser] = []

    static func == (lhs: Room, rhs: Room) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

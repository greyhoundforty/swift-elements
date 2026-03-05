import Foundation

struct MatrixUser: Identifiable, Hashable, Codable {
    let id: String          // Matrix ID: @user:server.org
    var displayName: String
    var avatarURL: URL?

    var initials: String {
        let words = displayName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    /// Local part of the Matrix ID (before the colon)
    var localpart: String {
        id.hasPrefix("@") ? String(id.dropFirst().prefix(while: { $0 != ":" })) : id
    }
}

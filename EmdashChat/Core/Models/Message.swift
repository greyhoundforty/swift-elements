import Foundation

// MARK: - MessageReply (quoted message reference)

struct MessageReply: Hashable {
    let eventId: String      // ID of the event being replied to
    let senderName: String   // Display name of the original sender
    let preview: String      // Truncated preview of the original message body
}

// MARK: - Message

struct Message: Identifiable, Hashable {
    let id: String          // Matrix event ID: $xxx:server.org
    let roomId: String
    let sender: MatrixUser
    let content: MessageContent
    let timestamp: Date
    var isFromCurrentUser: Bool = false
    var replyTo: MessageReply? = nil   // set when this is a reply

    /// Whether this message was sent within 5 min of `previous` by the same sender
    /// and neither has a reply header (which always breaks grouping visually).
    func isGrouped(with previous: Message?) -> Bool {
        guard let previous else { return false }
        guard replyTo == nil else { return false }  // replies always show header
        return sender.id == previous.sender.id
            && timestamp.timeIntervalSince(previous.timestamp) < 300
    }
}

// MARK: - MessageContent

enum MessageContent: Hashable {
    case text(String)
    case emote(String)
    case image(URL)
    case redacted
    case unknown(String)

    var preview: String {
        switch self {
        case .text(let s):   return s
        case .emote(let s):  return "* \(s)"
        case .image:         return "📷 Image"
        case .redacted:      return "Message deleted"
        case .unknown:       return ""
        }
    }
}

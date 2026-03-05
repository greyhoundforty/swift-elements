import SwiftUI

struct RoomRowView: View {
    let room: Room
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Avatar
            AvatarView(name: room.name, avatarURL: room.avatarURL, size: Theme.Size.avatarMd)

            // Name + last message
            VStack(alignment: .leading, spacing: 1) {
                Text(room.name)
                    .font(Theme.Font.roomName)
                    .lineLimit(1)

                if let last = room.lastMessage {
                    Text(lastMessagePreview(last))
                        .font(Theme.Font.roomMeta)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // Right column: timestamp + unread badge
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                if let last = room.lastMessage {
                    Text(last.timestamp, style: .relative)
                        .font(Theme.Font.timestamp)
                        .foregroundStyle(.tertiary)
                }
                UnreadBadge(count: room.unreadCount)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .frame(height: Theme.Size.rowHeight)
        .contentShape(Rectangle())
    }

    private func lastMessagePreview(_ msg: Message) -> String {
        if msg.isFromCurrentUser {
            return "You: \(msg.content.preview)"
        }
        return "\(msg.sender.displayName): \(msg.content.preview)"
    }
}

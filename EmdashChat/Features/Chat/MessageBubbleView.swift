import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let previousMessage: Message?
    @State private var showTimestamp = false

    @AppStorage("bubbleTheme") private var themeId: String = BubbleTheme.classic.rawValue
    private var activeTheme: BubbleTheme { BubbleTheme(rawValue: themeId) ?? .classic }

    private var isGrouped: Bool { message.isGrouped(with: previousMessage) }

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
            if message.isFromCurrentUser {
                Spacer(minLength: 60)
                bubble
            } else {
                if isGrouped {
                    Spacer().frame(width: Theme.Size.avatarLg)
                } else {
                    AvatarView(
                        name: message.sender.displayName,
                        avatarURL: message.sender.avatarURL,
                        size: Theme.Size.avatarLg
                    )
                }
                bubble
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, isGrouped ? 1 : Theme.Spacing.xs)
    }

    // MARK: - Bubble

    @ViewBuilder
    private var bubble: some View {
        VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 2) {
            // Sender name — first in a group, incoming only
            if !isGrouped && !message.isFromCurrentUser {
                Text(message.sender.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, Theme.Spacing.xs)
            }

            ZStack(alignment: message.isFromCurrentUser ? .bottomTrailing : .bottomLeading) {
                bubbleBackground
                    .overlay(alignment: message.isFromCurrentUser ? .bottomTrailing : .bottomLeading) {
                        if showTimestamp {
                            Text(message.timestamp, style: .time)
                                .font(Theme.Font.timestamp)
                                .foregroundStyle(
                                    message.isFromCurrentUser
                                        ? AnyShapeStyle(.white.opacity(0.7))
                                        : AnyShapeStyle(Color.secondary)
                                )
                                .padding(Theme.Spacing.xs)
                        }
                    }

                VStack(alignment: .leading, spacing: 0) {
                    // Reply quote block
                    if let reply = message.replyTo {
                        quoteBlock(reply)
                    }
                    // Message content
                    contentView
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, message.replyTo != nil ? Theme.Spacing.xs : Theme.Spacing.sm)
                        .padding(.bottom, showTimestamp ? 18 : Theme.Spacing.sm)
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { showTimestamp = hovering }
        }
    }

    // MARK: - Reply quote block

    @ViewBuilder
    private func quoteBlock(_ reply: MessageReply) -> some View {
        HStack(spacing: 0) {
            // Coloured left rail
            Rectangle()
                .fill(message.isFromCurrentUser ? Color.white.opacity(0.6) : activeTheme.outgoingColor)
                .frame(width: 3)
                .clipShape(Capsule())
                .padding(.leading, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)

            VStack(alignment: .leading, spacing: 1) {
                Text(reply.senderName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        message.isFromCurrentUser
                            ? AnyShapeStyle(Color.white.opacity(0.85))
                            : AnyShapeStyle(activeTheme.outgoingColor)
                    )
                Text(reply.preview)
                    .font(.system(size: 11))
                    .foregroundStyle(
                        message.isFromCurrentUser
                            ? AnyShapeStyle(Color.white.opacity(0.65))
                            : AnyShapeStyle(Color.secondary)
                    )
                    .lineLimit(2)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.top, Theme.Spacing.sm)
        .background(
            message.isFromCurrentUser
                ? Color.white.opacity(0.12)
                : activeTheme.outgoingColor.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.top, Theme.Spacing.xs)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        let textColor: Color = message.isFromCurrentUser
            ? activeTheme.outgoingTextColor
            : Theme.Color.incomingText

        switch message.content {
        case .text(let s):
            Text(s)
                .font(Theme.Font.messageBody)
                .foregroundStyle(textColor)
                .textSelection(.enabled)

        case .emote(let s):
            Text("* \(s)")
                .font(Theme.Font.messageBody.italic())
                .foregroundStyle(textColor.opacity(0.8))

        case .image(let url):
            AnimatedGIFView(url: url)
                .frame(width: 240, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Size.bubbleRadius - 4))

        case .redacted:
            Text("Message deleted")
                .font(Theme.Font.messageBody.italic())
                .foregroundStyle(textColor.opacity(0.5))

        case .unknown:
            Text("Unsupported message type")
                .font(Theme.Font.messageBody.italic())
                .foregroundStyle(textColor.opacity(0.5))
        }
    }

    // MARK: - Bubble background

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.isFromCurrentUser {
            RoundedRectangle(cornerRadius: Theme.Size.bubbleRadius)
                .fill(activeTheme.outgoingColor)
        } else {
            RoundedRectangle(cornerRadius: Theme.Size.bubbleRadius)
                .fill(Theme.Color.incomingBubble)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Size.bubbleRadius)
                        .strokeBorder(Theme.Color.divider, lineWidth: 0.5)
                )
        }
    }
}

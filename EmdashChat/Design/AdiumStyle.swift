import SwiftUI
import KeyboardShortcuts

// MARK: - Keyboard shortcut names
//
// Registered with the KeyboardShortcuts package so users can customize them
// via Settings → Keyboard. Defaults match the plan spec.

extension KeyboardShortcuts.Name {
    static let roomSearch    = Self("roomSearch",    default: .init(.k, modifiers: .command))
    static let newDM         = Self("newDM",         default: .init(.n, modifiers: .command))
    static let previousRoom  = Self("previousRoom",  default: .init(.leftBracket,  modifiers: .command))
    static let nextRoom      = Self("nextRoom",       default: .init(.rightBracket, modifiers: .command))
}

// MARK: - Adium-style visual constants

enum AdiumStyle {
    /// Room list sidebar width range
    static let sidebarMinWidth: CGFloat  = 200
    static let sidebarIdealWidth: CGFloat = 260
    static let sidebarMaxWidth: CGFloat  = 340

    /// Chat window default size
    static let chatDefaultWidth: CGFloat  = 720
    static let chatDefaultHeight: CGFloat = 520

    /// Avatar letter gradient pairs (top, bottom)
    static let avatarGradients: [(Color, Color)] = [
        (.blue,   Color(red: 0.1, green: 0.3, blue: 0.9)),
        (.purple, Color(red: 0.5, green: 0.1, blue: 0.8)),
        (.green,  Color(red: 0.1, green: 0.6, blue: 0.3)),
        (.orange, Color(red: 0.9, green: 0.5, blue: 0.1)),
        (.pink,   Color(red: 0.9, green: 0.3, blue: 0.5)),
        (.teal,   Color(red: 0.1, green: 0.6, blue: 0.7)),
    ]

    static func avatarGradient(for string: String) -> LinearGradient {
        let pair = avatarGradients[abs(string.hashValue) % avatarGradients.count]
        return LinearGradient(
            colors: [pair.0, pair.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - AvatarView

struct AvatarView: View {
    let name: String
    let avatarURL: URL?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(AdiumStyle.avatarGradient(for: name))
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - UnreadBadge

struct UnreadBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count < 100 ? "\(count)" : "99+")
                .font(Theme.Font.badge)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Theme.Color.unreadBadge, in: Capsule())
                .frame(minWidth: Theme.Size.badgeMinWidth)
        }
    }
}

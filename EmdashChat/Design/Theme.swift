import SwiftUI

// MARK: - Theme
//
// Central design token store. Reference these instead of magic values.

enum Theme {
    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 16
        static let xl: CGFloat  = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Typography
    enum Font {
        static let roomName   = SwiftUI.Font.system(size: 13, weight: .medium)
        static let roomMeta   = SwiftUI.Font.system(size: 11, weight: .regular)
        static let sectionHeader = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let messageBody = SwiftUI.Font.system(size: 13)
        static let timestamp  = SwiftUI.Font.system(size: 10)
        static let composer   = SwiftUI.Font.system(size: 13)
        static let badge      = SwiftUI.Font.system(size: 10, weight: .bold)
    }

    // MARK: - Sizing
    enum Size {
        static let avatarSm: CGFloat  = 24
        static let avatarMd: CGFloat  = 32
        static let avatarLg: CGFloat  = 36
        static let rowHeight: CGFloat = 44
        static let bubbleRadius: CGFloat = 16
        static let composerRadius: CGFloat = 18
        static let badgeMinWidth: CGFloat = 18
    }

    // MARK: - Colors
    enum Color {
        static let outgoingBubble = SwiftUI.Color.accentColor
        static let incomingBubble = SwiftUI.Color(NSColor.controlBackgroundColor)
        static let outgoingText   = SwiftUI.Color.white
        static let incomingText   = SwiftUI.Color.primary
        static let unreadBadge    = SwiftUI.Color.red
        static let selection      = SwiftUI.Color.accentColor.opacity(0.15)
        static let divider        = SwiftUI.Color(NSColor.separatorColor)
        static let composerBg     = SwiftUI.Color(NSColor.textBackgroundColor)
    }
}

// MARK: - Avatar color palette (deterministic from string hash)

extension SwiftUI.Color {
    static func avatarColor(for string: String) -> SwiftUI.Color {
        let palette: [SwiftUI.Color] = [.blue, .purple, .green, .orange, .pink, .teal, .indigo, .cyan]
        let index = abs(string.hashValue) % palette.count
        return palette[index]
    }
}

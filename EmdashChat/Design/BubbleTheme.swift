import SwiftUI

// MARK: - BubbleTheme
//
// Named color presets for outgoing message bubbles.
// Stored as a string in UserDefaults via @AppStorage("bubbleTheme").

enum BubbleTheme: String, CaseIterable, Identifiable {
    case classic   = "classic"   // System blue  (default, matches macOS accent)
    case purple    = "purple"    // Signal-purple
    case rose      = "rose"      // Warm rose
    case emerald   = "emerald"   // WhatsApp-green
    case amber     = "amber"     // Warm amber/orange
    case graphite  = "graphite"  // Dark gray, no colour
    case midnight  = "midnight"  // Deep navy blue

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic:  "Classic Blue"
        case .purple:   "Purple"
        case .rose:     "Rose"
        case .emerald:  "Emerald"
        case .amber:    "Amber"
        case .graphite: "Graphite"
        case .midnight: "Midnight"
        }
    }

    // MARK: - Colors

    var outgoingColor: Color {
        switch self {
        case .classic:  Color(red: 0.00, green: 0.48, blue: 1.00)   // iOS system blue
        case .purple:   Color(red: 0.45, green: 0.20, blue: 0.85)
        case .rose:     Color(red: 0.90, green: 0.25, blue: 0.45)
        case .emerald:  Color(red: 0.10, green: 0.65, blue: 0.35)
        case .amber:    Color(red: 0.95, green: 0.55, blue: 0.10)
        case .graphite: Color(red: 0.35, green: 0.35, blue: 0.38)
        case .midnight: Color(red: 0.05, green: 0.15, blue: 0.50)
        }
    }

    var outgoingTextColor: Color { .white }

    // Incoming bubbles share a single neutral style — only tint the border/background
    var incomingAccent: Color {
        switch self {
        case .amber, .rose: outgoingColor.opacity(0.12)
        default:            outgoingColor.opacity(0.08)
        }
    }
}

// MARK: - BubbleThemeSwatchView (for Settings picker)

struct BubbleThemeSwatch: View {
    let theme: BubbleTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.outgoingColor)
                        .frame(width: 48, height: 36)
                        .shadow(color: theme.outgoingColor.opacity(0.4), radius: 4, y: 2)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? Color.primary.opacity(0.8) : Color.clear, lineWidth: 2)
                )

                Text(theme.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

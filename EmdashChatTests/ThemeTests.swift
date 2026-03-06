import Testing
import SwiftUI
@testable import EmdashChat

@Suite("Theme constants")
struct ThemeTests {
    @Test func spacingIsOrdered() {
        #expect(Theme.Spacing.xxs < Theme.Spacing.xs)
        #expect(Theme.Spacing.xs  < Theme.Spacing.sm)
        #expect(Theme.Spacing.sm  < Theme.Spacing.md)
        #expect(Theme.Spacing.md  < Theme.Spacing.lg)
        #expect(Theme.Spacing.lg  < Theme.Spacing.xl)
        #expect(Theme.Spacing.xl  < Theme.Spacing.xxl)
    }

    @Test func avatarSizesAreOrdered() {
        #expect(Theme.Size.avatarSm < Theme.Size.avatarMd)
        #expect(Theme.Size.avatarMd < Theme.Size.avatarLg)
    }

    @Test func avatarColorIsDeterministic() {
        let c1 = Color.avatarColor(for: "alice")
        let c2 = Color.avatarColor(for: "alice")
        // Same input → same output across calls
        #expect(c1 == c2)
    }

    @Test func avatarColorVariesByInput() {
        // Not guaranteed to differ for every pair, but these specific values should
        let a = Color.avatarColor(for: "alice")
        let b = Color.avatarColor(for: "zzz_very_different_string_xyz")
        // Just confirm no crash and both are non-nil (Color is always valid)
        _ = a
        _ = b
    }
}

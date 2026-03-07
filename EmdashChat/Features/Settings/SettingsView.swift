import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(MatrixClient.self) private var matrixClient

    var body: some View {
        TabView {
            accountTab
                .tabItem { Label("Account", systemImage: "person.circle") }

            colorsTab
                .tabItem { Label("Colors", systemImage: "paintpalette") }

            gifTab
                .tabItem { Label("GIFs", systemImage: "photo.on.rectangle.angled") }

            shortcutsTab
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 500, height: 360)
    }

    // MARK: - Account tab

    @ViewBuilder
    private var accountTab: some View {
        Form {
            if let user = matrixClient.currentUser {
                Section("Signed In") {
                    LabeledContent("User ID", value: user.id)
                    if let session = matrixClient.session {
                        LabeledContent("Homeserver", value: session.homeserver)
                        if let deviceId = session.deviceId {
                            LabeledContent("Device ID", value: deviceId)
                        }
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await matrixClient.logout() }
                    }
                }
            } else {
                ContentUnavailableView("Not Signed In", systemImage: "person.slash")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Colors tab

    @ViewBuilder
    private var colorsTab: some View {
        BubbleColorSettingsView()
    }

    // MARK: - GIF tab

    @ViewBuilder
    private var gifTab: some View {
        GIFSettingsView()
    }

    // MARK: - Keyboard shortcuts tab

    @ViewBuilder
    private var shortcutsTab: some View {
        Form {
            Section("Navigation") {
                KeyboardShortcuts.Recorder("Search rooms", name: .roomSearch)
                KeyboardShortcuts.Recorder("Previous room", name: .previousRoom)
                KeyboardShortcuts.Recorder("Next room", name: .nextRoom)
            }

            Section("Messaging") {
                KeyboardShortcuts.Recorder("New direct message", name: .newDM)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - BubbleColorSettingsView

struct BubbleColorSettingsView: View {
    @AppStorage("bubbleTheme") private var themeId: String = BubbleTheme.classic.rawValue

    private var selectedTheme: BubbleTheme { BubbleTheme(rawValue: themeId) ?? .classic }

    let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Outgoing Message Color")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                ForEach(BubbleTheme.allCases) { theme in
                    BubbleThemeSwatch(
                        theme: theme,
                        isSelected: selectedTheme == theme,
                        action: { themeId = theme.rawValue }
                    )
                }
            }

            Divider()

            // Live preview
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Preview")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    // Incoming
                    VStack(alignment: .leading) {
                        Text("Alice")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Hey! How does this look?")
                            .font(.system(size: 12))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Color(NSColor.controlBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    }

                    Spacer()

                    // Outgoing
                    Text("Looking great! ✨")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedTheme.outgoingColor, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .animation(.easeInOut(duration: 0.2), value: themeId)
    }
}

// MARK: - GIFSettingsView

struct GIFSettingsView: View {
    @AppStorage("gifProvider") private var providerType = GIFProviderType.giphy
    @AppStorage("giphyAPIKey") private var giphyAPIKey = ""
    @AppStorage("klipyAPIKey") private var klipyAPIKey = ""

    @State private var testResult: String?
    @State private var isTesting = false

    private var currentAPIKey: Binding<String> {
        providerType == .giphy ? $giphyAPIKey : $klipyAPIKey
    }

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $providerType) {
                    ForEach(GIFProviderType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("GIF Provider")
            } footer: {
                Text("Type /gif in any chat to search. Results appear in a popover above the composer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    SecureField(providerType.keyPlaceholder, text: currentAPIKey)
                        .textFieldStyle(.roundedBorder)

                    Button("Test") {
                        Task { await testAPIKey() }
                    }
                    .disabled(currentAPIKey.wrappedValue.isEmpty || isTesting)
                }

                if let result = testResult {
                    Label(result, systemImage: result.hasPrefix("✓") ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(result.hasPrefix("✓") ? .green : .red)
                }

                if let keyURL = providerType.keyURL {
                    Link("Get a free \(providerType.displayName) API key →", destination: keyURL)
                        .font(.caption)
                }
            } header: {
                Text("API Key")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: providerType) { _, _ in testResult = nil }
    }

    // MARK: - Test

    func testAPIKey() async {
        isTesting = true
        testResult = nil
        let service: any GIFProvider = providerType == .giphy
            ? GiphyService(apiKey: giphyAPIKey)
            : KlipyService(apiKey: klipyAPIKey)
        do {
            let results = try await service.trending(limit: 1)
            testResult = results.isEmpty ? "✓ Connected (no results)" : "✓ Connected — \(providerType.displayName) is working"
        } catch {
            testResult = "✗ \(error.localizedDescription)"
        }
        isTesting = false
    }
}

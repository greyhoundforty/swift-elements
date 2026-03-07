import SwiftUI

struct ComposerView: View {
    @Binding var text: String
    @Binding var replyingTo: MessageReply?
    let onSend: () -> Void
    var onSendGIF: ((GIFResult) -> Void)?

    @FocusState private var isFocused: Bool
    @State private var showGIFPicker = false

    // GIF provider settings
    @AppStorage("gifProvider") private var providerType = GIFProviderType.giphy
    @AppStorage("giphyAPIKey") private var giphyAPIKey = ""
    @AppStorage("klipyAPIKey") private var klipyAPIKey = ""

    var body: some View {
        VStack(spacing: 0) {
            // Reply bar — shown when replying to a message
            if let reply = replyingTo {
                replyBar(reply)
                Divider()
            }
            composerRow
        }
        .background(.bar)
    }

    // MARK: - Reply bar

    @ViewBuilder
    private func replyBar(_ reply: MessageReply) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 1) {
                Text("Replying to \(reply.senderName)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(reply.preview)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button { replyingTo = nil } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Color.accentColor.opacity(0.06))
    }

    // MARK: - Composer row

    private var composerRow: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            // Text input
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Message… (type /gif to search GIFs)")
                        .font(Theme.Font.composer)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 7)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(Theme.Font.composer)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 34, maxHeight: 120)
                    .fixedSize(horizontal: false, vertical: true)
                    .onKeyPress(.return) {
                        if NSEvent.modifierFlags.contains(.shift) {
                            return .ignored  // Shift+Return → newline
                        }
                        if gifQuery != nil {
                            // Return while GIF picker is open — dismiss without sending
                            showGIFPicker = false
                            text = ""
                            return .handled
                        }
                        send()
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        guard showGIFPicker else { return .ignored }
                        showGIFPicker = false
                        text = ""
                        return .handled
                    }
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.Color.composerBg, in: RoundedRectangle(cornerRadius: Theme.Size.composerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Size.composerRadius)
                    .strokeBorder(
                        isFocused
                            ? (showGIFPicker ? Color.purple.opacity(0.5) : Color.accentColor.opacity(0.5))
                            : Theme.Color.divider,
                        lineWidth: 1
                    )
            )
            .onChange(of: text) { _, _ in
                showGIFPicker = gifQuery != nil
            }
            .popover(isPresented: $showGIFPicker, arrowEdge: .top) {
                gifPickerContent
            }

            // Send button
            Button(action: send) {
                Image(systemName: showGIFPicker ? "xmark.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        canSend
                            ? AnyShapeStyle(showGIFPicker ? Color.purple : Color.accentColor)
                            : AnyShapeStyle(Color(NSColor.tertiaryLabelColor))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSend && !showGIFPicker)
            .keyboardShortcut(.return, modifiers: .command)
            .help(showGIFPicker ? "Cancel GIF search" : "Send message")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - GIF picker content

    @ViewBuilder
    private var gifPickerContent: some View {
        let apiKey = providerType == .giphy ? giphyAPIKey : klipyAPIKey
        if apiKey.isEmpty {
            GIFPickerNoKeyView(providerType: providerType)
        } else {
            GIFPickerView(
                query: gifQuery ?? "",
                service: currentService,
                onSelect: { result in
                    showGIFPicker = false
                    text = ""
                    onSendGIF?(result)
                }
            )
        }
    }

    // MARK: - Helpers

    private var gifQuery: String? {
        guard text.hasPrefix("/gif") else { return nil }
        // "/gif" with or without trailing space/term
        let after = text.dropFirst(4)
        if after.isEmpty { return "" }
        guard after.hasPrefix(" ") else { return nil }
        return String(after.dropFirst())
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentService: any GIFProvider {
        switch providerType {
        case .giphy: GiphyService(apiKey: giphyAPIKey)
        case .klipy: KlipyService(apiKey: klipyAPIKey)
        }
    }

    private func send() {
        guard canSend else { return }
        onSend()
    }
}

import SwiftUI

// MARK: - Scroll offset tracking (macOS 14 compatible)

private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct MessageListView: View {
    let messages: [Message]
    let isLoadingHistory: Bool
    let onScrollToTop: () async -> Void
    var onReply: ((Message) -> Void)?

    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var containerHeight: CGFloat = 0
    @State private var scrollProxy: ScrollViewProxy?

    private var isAtBottom: Bool {
        contentHeight <= containerHeight || scrollOffset >= contentHeight - containerHeight - 60
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            GeometryReader { outer in
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if isLoadingHistory {
                                ProgressView().padding().id("top-spinner")
                            }

                            ForEach(Array(messages.enumerated()), id: \.element.id) { idx, message in
                                MessageBubbleView(
                                    message: message,
                                    previousMessage: idx > 0 ? messages[idx - 1] : nil
                                )
                                .id(message.id)
                                .contextMenu { contextMenu(for: message) }
                            }

                            Color.clear.frame(height: 1).id("bottom-anchor")
                        }
                        .background(
                            GeometryReader { inner in
                                Color.clear
                                    .preference(key: ScrollOffsetKey.self,
                                                value: -inner.frame(in: .named("scroll")).minY)
                                    .onAppear { contentHeight = inner.size.height }
                                    .onChange(of: inner.size.height) { _, h in contentHeight = h }
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetKey.self) { offset in
                        let prev = scrollOffset
                        scrollOffset = max(0, offset)
                        if prev > 80 && scrollOffset < 80 {
                            Task { await onScrollToTop() }
                        }
                    }
                    .onAppear {
                        containerHeight = outer.size.height
                        scrollProxy = proxy
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo("bottom-anchor", anchor: .bottom)
                        }
                    }
                    .onChange(of: outer.size.height) { _, h in containerHeight = h }
                    .onChange(of: messages.count) { _, _ in
                        if isAtBottom {
                            withAnimation { proxy.scrollTo("bottom-anchor", anchor: .bottom) }
                        }
                    }
                }
            }

            // Jump-to-bottom FAB
            if !isAtBottom {
                Button {
                    withAnimation { scrollProxy?.scrollTo("bottom-anchor", anchor: .bottom) }
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.accentColor)
                        .background(Circle().fill(.background))
                        .shadow(radius: 4)
                }
                .buttonStyle(.plain)
                .padding(Theme.Spacing.md)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenu(for message: Message) -> some View {
        Button {
            onReply?(message)
        } label: {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }

        Divider()

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.content.preview, forType: .string)
        } label: {
            Label("Copy Text", systemImage: "doc.on.doc")
        }
        .disabled(message.content.preview.isEmpty)
    }
}

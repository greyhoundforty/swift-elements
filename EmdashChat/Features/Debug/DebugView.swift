import SwiftUI

struct DebugView: View {
    @Environment(MatrixClient.self) private var client

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Debug")
                    .font(.headline)
                Spacer()
                Button("Clear") { client.clearDebugLog() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            // Status row
            HStack(spacing: 16) {
                label("User", client.currentUser?.id ?? "—")
                label("Rooms", "\(client.rooms.count)")
                label("Sync", client.syncState)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)

            Divider()

            // Log
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(client.debugLog.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(color(for: line))
                                .textSelection(.enabled)
                                .id(idx)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: client.debugLog.count) { _, _ in
                    if let last = client.debugLog.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 300)
    }

    private func label(_ title: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(title + ":").foregroundStyle(.secondary)
            Text(value).bold()
        }
    }

    private func color(for line: String) -> Color {
        if line.contains("error") || line.contains("Error") { return .red }
        if line.contains("warn") || line.contains("Warn") { return .orange }
        if line.contains("rooms updated") || line.contains("roomList") { return .green }
        if line.contains("syncService") || line.contains("loadingState") { return .blue }
        return .primary
    }
}

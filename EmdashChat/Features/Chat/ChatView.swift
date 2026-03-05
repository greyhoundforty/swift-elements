import SwiftUI

struct ChatView: View {
    let roomId: String

    @Environment(MatrixClient.self) private var matrixClient
    @State private var viewModel: ChatViewModel

    init(roomId: String) {
        self.roomId = roomId
        _viewModel = State(initialValue: ChatViewModel(roomId: roomId))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            MessageListView(
                messages: viewModel.messages,
                isLoadingHistory: viewModel.isLoadingHistory,
                onScrollToTop: { await viewModel.loadOlderMessages() },
                onReply: { message in viewModel.beginReply(to: message) }
            )

            Divider()

            ComposerView(
                text: $viewModel.composerText,
                replyingTo: $viewModel.replyingTo,
                onSend: { Task { await viewModel.send(client: matrixClient) } },
                onSendGIF: { gif in Task { await viewModel.sendGIF(gif, client: matrixClient) } }
            )
        }
        .frame(
            minWidth: 480,
            idealWidth: AdiumStyle.chatDefaultWidth,
            minHeight: 360,
            idealHeight: AdiumStyle.chatDefaultHeight
        )
        .navigationTitle(viewModel.room?.name ?? roomId)
        .task {
            await viewModel.onAppear(client: matrixClient)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let room = viewModel.room {
                AvatarView(name: room.name, avatarURL: room.avatarURL, size: Theme.Size.avatarMd)
                VStack(alignment: .leading, spacing: 1) {
                    Text(room.name)
                        .font(.headline)
                    if let topic = room.topic {
                        Text(topic)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                Text(roomId).font(.headline).foregroundStyle(.secondary)
            }

            Spacer()

            // Simulation toggle (testing aid)
            Button {
                viewModel.toggleSimulation()
            } label: {
                Label(
                    viewModel.isSimulating ? "Stop Simulation" : "Simulate Users",
                    systemImage: viewModel.isSimulating ? "stop.circle" : "person.2.wave.2"
                )
                .font(.caption)
                .foregroundStyle(viewModel.isSimulating ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .help(viewModel.isSimulating
                  ? "Stop simulated responses"
                  : "Simulate other users responding (for testing)")

            // Member count
            if let room = viewModel.room, !room.members.isEmpty {
                Label("\(room.members.count)", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.bar)
    }
}

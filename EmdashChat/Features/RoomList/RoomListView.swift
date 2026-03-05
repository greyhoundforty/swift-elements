import SwiftUI
import KeyboardShortcuts

struct RoomListView: View {
    @Environment(MatrixClient.self) private var matrixClient
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel = RoomListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showSearch {
                searchBar
            }

            if matrixClient.isLoggedIn {
                roomList
            } else {
                loginPlaceholder
            }
        }
        .frame(
            minWidth: AdiumStyle.sidebarMinWidth,
            idealWidth: AdiumStyle.sidebarIdealWidth,
            maxWidth: AdiumStyle.sidebarMaxWidth
        )
        .background(.ultraThinMaterial)
        // Global keyboard shortcuts via KeyboardShortcuts package
        .onAppear {
            KeyboardShortcuts.onKeyUp(for: .roomSearch) {
                Task { @MainActor in
                    viewModel.showSearch.toggle()
                    if !viewModel.showSearch { viewModel.searchText = "" }
                }
            }
            KeyboardShortcuts.onKeyUp(for: .previousRoom) {
                Task { @MainActor in
                    viewModel.selectPrevious(rooms: matrixClient.rooms)
                    openSelectedRoom()
                }
            }
            KeyboardShortcuts.onKeyUp(for: .nextRoom) {
                Task { @MainActor in
                    viewModel.selectNext(rooms: matrixClient.rooms)
                    openSelectedRoom()
                }
            }
        }
        .sheet(isPresented: .constant(!matrixClient.isLoggedIn)) {
            LoginView()
                .environment(matrixClient)
        }
        .task {
            await matrixClient.restoreSession()
        }
    }

    // MARK: - Search bar

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(.system(size: 12))

            TextField("Search rooms…", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(Theme.Font.roomName)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.regularMaterial)

        Divider()
    }

    // MARK: - Room list

    @ViewBuilder
    private var roomList: some View {
        List(selection: $viewModel.selectedRoomId) {
            let dms    = viewModel.dmRooms(from: matrixClient.rooms)
            let groups = viewModel.groupRooms(from: matrixClient.rooms)

            if !dms.isEmpty {
                Section {
                    ForEach(dms) { room in
                        RoomRowView(room: room, isSelected: viewModel.selectedRoomId == room.id)
                            .tag(room.id)
                    }
                } header: {
                    Text("Direct Messages")
                        .font(Theme.Font.sectionHeader)
                        .foregroundStyle(.secondary)
                }
            }

            if !groups.isEmpty {
                Section {
                    ForEach(groups) { room in
                        RoomRowView(room: room, isSelected: viewModel.selectedRoomId == room.id)
                            .tag(room.id)
                    }
                } header: {
                    Text("Rooms")
                        .font(Theme.Font.sectionHeader)
                        .foregroundStyle(.secondary)
                }
            }

            if matrixClient.rooms.isEmpty {
                ContentUnavailableView(
                    "No Rooms",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Sync is starting…")
                )
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .onChange(of: viewModel.selectedRoomId) { _, newId in
            guard let id = newId else { return }
            openWindow(value: id)
        }
    }

    // MARK: - Not-logged-in placeholder

    @ViewBuilder
    private var loginPlaceholder: some View {
        ContentUnavailableView {
            Label("Not Connected", systemImage: "network.slash")
        } description: {
            Text("Sign in to your Matrix account")
        }
    }

    // MARK: - Helpers

    private func openSelectedRoom() {
        guard let id = viewModel.selectedRoomId else { return }
        openWindow(value: id)
    }
}

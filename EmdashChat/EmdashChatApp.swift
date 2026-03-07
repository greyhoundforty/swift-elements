import SwiftUI

@main
struct EmdashChatApp: App {
    @State private var matrixClient = MatrixClient.shared

    var body: some Scene {
        // Adium-style floating room list — primary window, opens on launch
        Window("Rooms", id: "room-list") {
            RoomListView()
                .environment(matrixClient)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: AdiumStyle.sidebarIdealWidth, height: 600)
        .defaultPosition(.topLeading)

        // Per-room chat windows — opened programmatically via openWindow(value: roomId)
        WindowGroup(for: String.self) { $roomId in
            if let id = roomId {
                ChatView(roomId: id)
                    .environment(matrixClient)
            }
        }
        .defaultSize(width: AdiumStyle.chatDefaultWidth, height: AdiumStyle.chatDefaultHeight)

        // Debug window — open via Window menu
        Window("Debug", id: "debug") {
            DebugView()
                .environment(matrixClient)
        }
        .defaultSize(width: 520, height: 360)
        .defaultPosition(.bottomLeading)

        // Settings (Cmd+,)
        Settings {
            SettingsView()
                .environment(matrixClient)
        }
    }
}

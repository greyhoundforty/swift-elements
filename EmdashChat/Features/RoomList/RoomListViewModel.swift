import Foundation
import Observation

@Observable
@MainActor
final class RoomListViewModel {
    var searchText    = ""
    var showSearch    = false
    var selectedRoomId: String?

    // MARK: - Filtered views

    func filteredRooms(from rooms: [Room]) -> [Room] {
        guard !searchText.isEmpty else { return rooms }
        return rooms.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func dmRooms(from rooms: [Room]) -> [Room] {
        filteredRooms(from: rooms).filter { $0.isDM }
    }

    func groupRooms(from rooms: [Room]) -> [Room] {
        filteredRooms(from: rooms).filter { !$0.isDM }
    }

    // MARK: - Keyboard navigation

    func selectPrevious(rooms: [Room]) {
        let all = filteredRooms(from: rooms)
        guard !all.isEmpty else { return }
        if let id = selectedRoomId, let idx = all.firstIndex(where: { $0.id == id }) {
            selectedRoomId = all[max(0, idx - 1)].id
        } else {
            selectedRoomId = all.first?.id
        }
    }

    func selectNext(rooms: [Room]) {
        let all = filteredRooms(from: rooms)
        guard !all.isEmpty else { return }
        if let id = selectedRoomId, let idx = all.firstIndex(where: { $0.id == id }) {
            selectedRoomId = all[min(all.count - 1, idx + 1)].id
        } else {
            selectedRoomId = all.last?.id
        }
    }
}

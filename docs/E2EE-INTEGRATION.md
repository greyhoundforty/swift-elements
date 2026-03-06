# E2EE Integration — Next Steps

This document is the implementation guide for wiring the real `matrix-rust-sdk` into
EmdashChat and enabling end-to-end encryption. All crypto (Olm/Megolm) is handled
transparently by the SDK — no cryptography code is written by hand.

---

## Prerequisites

- Xcode 16+ with macOS 14 SDK
- `mise trust` run in the worktree root
- ~200 MB disk space for the SDK binary download
- A Matrix account on any homeserver for smoke-testing (matrix.org works)

---

## Step 1 — Link the SDK

In `project.yml`, uncomment the two `MatrixRustSDK` blocks:

```yaml
packages:
  MatrixRustSDK:
    url: https://github.com/matrix-org/matrix-rust-components-swift
    from: "1.0.0"

targets:
  EmdashChat:
    dependencies:
      - package: MatrixRustSDK
        product: MatrixRustSDK
```

Then regenerate the Xcode project:

```bash
xcodegen
```

Xcode will resolve and download the XCFramework on first build (~200 MB, one-time).

> **Note:** Check the [matrix-rust-components-swift releases](https://github.com/matrix-org/matrix-rust-components-swift/releases)
> for the latest stable tag and pin to it rather than `from: "1.0.0"` if a newer
> version is available.

---

## Step 2 — Add the import

Add to the top of each file listed below:

```swift
import MatrixRustSDK
```

Files that need it:
- `Core/Matrix/MatrixClient.swift`
- `Core/Matrix/AuthStore.swift`
- `Core/Matrix/SyncManager.swift`
- `Features/Chat/ChatViewModel.swift`

---

## Step 3 — Replace the 5 stubs

### 3a. `MatrixClient.login()` — `MatrixClient.swift:40`

Replace the fake delay with real SDK auth:

```swift
func login(homeserver: String, username: String, password: String) async throws {
    let client = try await ClientBuilder()
        .homeserverUrl(url: homeserver)
        .sessionDelegate(sessionDelegate: authStore)
        .build()

    try await client.matrixAuth().login(
        username: username,
        password: password,
        initialDeviceName: "EmdashChat macOS",
        deviceId: nil
    )

    self.sdkClient = client
    try authStore.save(session: client.session())
    self.session = MatrixSession(from: client.session())
    await syncManager.start(client: client)
}
```

Store `sdkClient` as a property on `MatrixClient`:
```swift
private var sdkClient: Client?
```

---

### 3b. `MatrixClient.restoreSession()` — `MatrixClient.swift:67`

```swift
func restoreSession() async throws {
    guard let stored = try authStore.load() else { return }

    let client = try await ClientBuilder()
        .homeserverUrl(url: stored.homeserverUrl)
        .sessionDelegate(sessionDelegate: authStore)
        .build()

    try await client.restoreSession(session: stored.toSDKSession())

    self.sdkClient = client
    self.session = stored
    await syncManager.start(client: client)
}
```

`AuthStore` needs two additions:
- `toSDKSession() -> Session` — maps the stored `MatrixSession` back to the SDK `Session` type
- Conform `AuthStore` to `ClientSessionDelegate` so the SDK can auto-refresh tokens:

```swift
extension AuthStore: ClientSessionDelegate {
    func retrieveSessionFromKeychain(userId: String) throws -> Session {
        guard let s = try load() else { throw AuthError.noSession }
        return s.toSDKSession()
    }
    func saveSessionInKeychain(session: Session) {
        try? save(session: MatrixSession(from: session))
    }
}
```

---

### 3c. `SyncManager.start()` — `SyncManager.swift:20`

Replace mock room population with real Sliding Sync:

```swift
func start(client: Client) async {
    self.client = client

    let roomListService = client.roomListService()
    let roomList = try? await roomListService.allRooms()

    // Subscribe to room list updates
    roomListUpdateTask = Task {
        for await diff in roomList!.entriesWithDynamicAdapters(pageSize: 50, listener: ...) {
            await MainActor.run {
                applyDiff(diff)
            }
        }
    }

    // Start the sync loop
    syncTask = Task {
        let syncService = try? await client.syncService().finish()
        await syncService?.start()
    }
}

private func applyDiff(_ diffs: [RoomListEntriesUpdate]) {
    for diff in diffs {
        switch diff {
        case .append(let rooms): /* append to MatrixClient.rooms */
        case .remove(let index): /* remove from MatrixClient.rooms */
        case .reset(let rooms):  /* replace MatrixClient.rooms */
        default: break
        }
    }
}
```

> **E2EE note:** The sync service automatically handles key download, Olm session
> setup, and Megolm key claims. No extra steps needed for encrypted rooms.

---

### 3d. `ChatViewModel.onAppear()` — `ChatViewModel.swift:28`

Replace mock message loading with a live timeline subscription:

```swift
func onAppear(roomId: String) async throws {
    guard let client = MatrixClient.shared.sdkClient else { return }

    let room = try await client.getRoom(roomId: roomId)
    let timeline = try await room.timeline()

    timelineTask = Task {
        for await diff in timeline.timelineDiffReceiver() {
            await MainActor.run {
                applyTimelineDiff(diff)
            }
        }
    }

    try await timeline.paginateBackwards(opts: .simpleRequest(eventLimit: 50))
}

private func applyTimelineDiff(_ diffs: [TimelineDiff]) {
    for diff in diffs {
        switch diff.change() {
        case .append:
            if let items = diff.append() {
                messages.append(contentsOf: items.compactMap(Message.init(timelineItem:)))
            }
        case .reset:
            messages = diff.reset()?.compactMap(Message.init(timelineItem:)) ?? []
        default: break
        }
    }
}
```

Add a `Message.init?(timelineItem: TimelineItem)` factory that unwraps
`timelineItem.asEvent()?.content()` and maps `RoomMessageEventContent` to `MessageContent`.
E2EE decryption is done automatically before the item reaches the timeline.

---

### 3e. `ChatViewModel.send()` — `ChatViewModel.swift:79`

```swift
func send(roomId: String) async throws {
    guard !composerText.isEmpty,
          let client = MatrixClient.shared.sdkClient else { return }

    let room = try await client.getRoom(roomId: roomId)
    let timeline = try await room.timeline()
    let content = RoomMessageEventContent.text(body: composerText)
    try await timeline.send(msg: content)
    composerText = ""
}
```

For GIF send (`ChatViewModel.swift:99`), upload the GIF via MXC first:

```swift
func sendGIF(url: URL, roomId: String) async throws {
    guard let client = MatrixClient.shared.sdkClient else { return }
    let data = try Data(contentsOf: url)
    let mxcUri = try await client.uploadMedia(
        mimeType: "image/gif",
        data: data,
        progressWatcher: nil
    )
    let room = try await client.getRoom(roomId: roomId)
    let timeline = try await room.timeline()
    let content = RoomMessageEventContent.image(
        body: "image.gif",
        source: MediaSource(url: mxcUri),
        info: nil
    )
    try await timeline.send(msg: content)
}
```

---

## Step 4 — Crypto store path

The SDK needs a writable directory for its crypto store (Olm account, session keys).
Set this in the `ClientBuilder` chain:

```swift
ClientBuilder()
    .homeserverUrl(url: homeserver)
    .sessionDelegate(sessionDelegate: authStore)
    .sessionPath(path: cryptoStorePath())   // <-- add this
    .build()
```

```swift
private func cryptoStorePath() -> String {
    let appSupport = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dir = appSupport.appendingPathComponent("EmdashChat/crypto", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.path
}
```

---

## Step 5 — Entitlements

The Keychain entitlement is already present in `EmdashChat.entitlements`.
No additional entitlements are required for E2EE.

---

## Step 6 — Verification checklist

- [ ] `mise run build` compiles with `MatrixRustSDK` linked (no stubs needed)
- [ ] Login with a real matrix.org account succeeds and session is restored on relaunch
- [ ] Room list populates with real rooms from the homeserver
- [ ] Messages in an **unencrypted** room display correctly
- [ ] Messages in an **encrypted** room display correctly (E2EE transparent)
- [ ] Sending a message in an unencrypted room delivers to Element/another client
- [ ] Sending a message in an encrypted room delivers and is readable in Element
- [ ] GIF send appears in Element as an inline image
- [ ] Logging out clears Keychain + crypto store

---

## Stub reference map

| File | Line | Stub description |
|---|---|---|
| `Core/Matrix/MatrixClient.swift` | 40 | `login()` — fake delay |
| `Core/Matrix/MatrixClient.swift` | 67 | `restoreSession()` — no SDK restore |
| `Core/Matrix/SyncManager.swift` | 20 | `start()` — mock rooms |
| `Features/Chat/ChatViewModel.swift` | 28 | `onAppear()` — mock timeline |
| `Features/Chat/ChatViewModel.swift` | 79, 99 | `send()` / GIF send — optimistic only |

---

## References

- [matrix-rust-components-swift](https://github.com/matrix-org/matrix-rust-components-swift)
- [matrix-rust-sdk Rust docs](https://matrix-org.github.io/matrix-rust-sdk/)
- [Matrix Client-Server spec — E2EE](https://spec.matrix.org/v1.9/client-server-api/#end-to-end-encryption)
- [Element X iOS](https://github.com/element-hq/element-x-ios) — reference implementation using the same SDK

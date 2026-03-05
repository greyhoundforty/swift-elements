import SwiftUI
import AppKit

// MARK: - AnimatedGIFView
//
// NSImageView wrapper that properly plays animated GIFs on macOS.
// AsyncImage doesn't animate GIFs; NSImageView does natively.

struct AnimatedGIFView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.animates = true
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.05).cgColor
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        context.coordinator.load(url: url, into: nsView)
    }

    // MARK: - Coordinator handles download + cancellation

    final class Coordinator {
        private var currentURL: URL?
        private var task: Task<Void, Never>?

        func load(url: URL, into imageView: NSImageView) {
            guard url != currentURL else { return }
            currentURL = url
            task?.cancel()
            task = Task {
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      !Task.isCancelled,
                      let image = NSImage(data: data)
                else { return }
                await MainActor.run {
                    imageView.image = image
                }
            }
        }
    }
}

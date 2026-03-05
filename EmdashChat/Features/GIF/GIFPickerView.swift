import SwiftUI

// MARK: - GIFPickerViewModel

@Observable
@MainActor
final class GIFPickerViewModel {
    var results: [GIFResult] = []
    var isLoading = false
    var errorMessage: String?

    private var page = 0
    private var lastQuery = ""

    func load(query: String, service: any GIFProvider) async {
        // Reset page when query changes
        if query != lastQuery { page = 0 }
        lastQuery = query
        await fetch(service: service)
    }

    func shuffle(service: any GIFProvider) async {
        page += 1
        await fetch(service: service)
    }

    private func fetch(service: any GIFProvider) async {
        isLoading = true
        errorMessage = nil
        do {
            results = lastQuery.isEmpty
                ? try await service.trending(limit: 9)
                : try await service.search(lastQuery, limit: 9, offset: page * 9)
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
        isLoading = false
    }
}

// MARK: - GIFPickerView

struct GIFPickerView: View {
    let query: String
    let service: any GIFProvider
    let onSelect: (GIFResult) -> Void

    @State private var viewModel = GIFPickerViewModel()
    @State private var selectedId: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 360, height: 310)
        .task(id: query) {
            await viewModel.load(query: query, service: service)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "arrow.2.squarepath")
                .foregroundStyle(.secondary)
                .font(.system(size: 11))

            Text(query.isEmpty ? "Trending GIFs" : "GIFs: \(query)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            // Shuffle button
            Button {
                Task { await viewModel.shuffle(service: service) }
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .help("Shuffle results")

            // Powered-by label
            Text("via GIPHY")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.bar)
    }

    // MARK: - Content area

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.results.isEmpty {
            loadingView
        } else if let error = viewModel.errorMessage {
            errorView(error)
        } else if viewModel.results.isEmpty {
            emptyView
        } else {
            grid
        }
    }

    @ViewBuilder
    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(viewModel.results) { result in
                    GIFGridItemView(
                        result: result,
                        isSelected: selectedId == result.id,
                        onTap: {
                            selectedId = result.id
                            // Small delay so selection highlight is visible before dismiss
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                onSelect(result)
                            }
                        }
                    )
                    .onHover { hovering in
                        if hovering { selectedId = result.id }
                    }
                }
            }
            .padding(4)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) {
            // Loading indicator for shuffle/pagination
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ProgressView()
            Text("Loading GIFs…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't Load GIFs", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await viewModel.load(query: query, service: service) }
            }
        }
    }

    @ViewBuilder
    private var emptyView: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "rectangle.slash",
            description: Text("Try a different search term")
        )
    }
}

// MARK: - No-API-key placeholder

struct GIFPickerNoKeyView: View {
    let providerType: GIFProviderType
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "key.slash")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No API Key")
                .font(.headline)

            Text("Add a \(providerType.displayName) API key in Settings to use GIFs.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                openSettings()
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 360, height: 220)
    }
}

import Foundation

// MARK: - GIFResult

struct GIFResult: Identifiable, Hashable, Sendable {
    let id: String
    let previewURL: URL   // small rendition — used in picker grid
    let fullURL: URL      // full-size — used when sending
    let width: Int
    let height: Int

    /// Aspect ratio for proportional layout
    var aspectRatio: CGFloat {
        height > 0 ? CGFloat(width) / CGFloat(height) : 1.0
    }
}

// MARK: - GIFProvider protocol

protocol GIFProvider: Sendable {
    func search(_ query: String, limit: Int, offset: Int) async throws -> [GIFResult]
    func trending(limit: Int) async throws -> [GIFResult]
}

// MARK: - Provider type (stored in UserDefaults via @AppStorage)

enum GIFProviderType: String, CaseIterable, Identifiable {
    case giphy = "giphy"
    case klipy = "klipy"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .giphy: "GIPHY"
        case .klipy: "Klipy"
        }
    }

    var keyURL: URL? {
        switch self {
        case .giphy: URL(string: "https://developers.giphy.com/dashboard/")
        case .klipy: URL(string: "https://partner.klipy.com/")
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .giphy: "Paste your GIPHY API key…"
        case .klipy: "Paste your Klipy API key…"
        }
    }
}

// MARK: - Shared errors

enum GIFError: LocalizedError {
    case missingAPIKey
    case badResponse(Int)
    case noResults

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:        return "No API key configured. Add one in Settings → GIFs."
        case .badResponse(let code): return "API error (HTTP \(code))"
        case .noResults:             return "No GIFs found"
        }
    }
}

// MARK: - Shared fetch helper

extension URLSession {
    func fetchJSON<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await data(from: url)
        guard let http = response as? HTTPURLResponse else { throw GIFError.badResponse(0) }
        guard http.statusCode == 200 else { throw GIFError.badResponse(http.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

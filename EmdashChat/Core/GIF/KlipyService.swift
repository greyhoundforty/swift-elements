import Foundation

// MARK: - KlipyService
//
// Wraps the Klipy GIF API — a drop-in Tenor replacement built by ex-Tenor employees.
// Get a free key at: https://partner.klipy.com/
//
// Klipy mirrors the Tenor v2 API structure; just swap the base URL.
//
// Search:   GET https://api.klipy.com/v2/gifs/search?q=TERM&key=KEY&limit=N
// Featured: GET https://api.klipy.com/v2/gifs/featured?key=KEY&limit=N

struct KlipyService: GIFProvider {
    let apiKey: String

    private static let base = "https://api.klipy.com/v2/gifs"

    func search(_ query: String, limit: Int = 9, offset: Int = 0) async throws -> [GIFResult] {
        guard !apiKey.isEmpty else { throw GIFError.missingAPIKey }
        let url = try buildURL(
            path: "search",
            extra: ["q": query, "pos": offset > 0 ? "\(offset)" : nil].compactMapValues { $0 },
            limit: limit
        )
        let response: KlipyResponse = try await URLSession.shared.fetchJSON(url)
        return response.results.compactMap(\.gifResult)
    }

    func trending(limit: Int = 9) async throws -> [GIFResult] {
        guard !apiKey.isEmpty else { throw GIFError.missingAPIKey }
        let url = try buildURL(path: "featured", extra: [:], limit: limit)
        let response: KlipyResponse = try await URLSession.shared.fetchJSON(url)
        return response.results.compactMap(\.gifResult)
    }

    // MARK: - Private

    private func buildURL(path: String, extra: [String: String], limit: Int) throws -> URL {
        var comps = URLComponents(string: "\(Self.base)/\(path)")!
        var items: [URLQueryItem] = [
            .init(name: "key", value: apiKey),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "media_filter", value: "gif,nanogif"),  // 70% smaller payload
            .init(name: "contentfilter", value: "medium"),
        ]
        items += extra.map { URLQueryItem(name: $0.key, value: $0.value) }
        comps.queryItems = items
        guard let url = comps.url else { throw URLError(.badURL) }
        return url
    }
}

// MARK: - Codable response models (mirrors Tenor v2 schema)

private struct KlipyResponse: Decodable {
    let results: [KlipyGIF]
}

private struct KlipyGIF: Decodable {
    let id: String
    let mediaFormats: [String: KlipyFormat]

    enum CodingKeys: String, CodingKey {
        case id
        case mediaFormats = "media_formats"
    }

    var gifResult: GIFResult? {
        // Prefer nanogif for preview (small), gif for send (full)
        guard
            let preview = mediaFormats["nanogif"] ?? mediaFormats["gif"],
            let full    = mediaFormats["gif"],
            let previewURL = URL(string: preview.url),
            let fullURL    = URL(string: full.url)
        else { return nil }
        let dims = full.dims ?? [200, 150]
        return GIFResult(
            id: id,
            previewURL: previewURL,
            fullURL: fullURL,
            width: dims.first ?? 200,
            height: dims.dropFirst().first ?? 150
        )
    }
}

private struct KlipyFormat: Decodable {
    let url: String
    let dims: [Int]?
}

import Foundation

// MARK: - GiphyService
//
// Wraps the Giphy v1 REST API.
// Get a free key at: https://developers.giphy.com/dashboard/
//
// Search:   GET https://api.giphy.com/v1/gifs/search?api_key=KEY&q=TERM&limit=N&offset=N&rating=g
// Trending: GET https://api.giphy.com/v1/gifs/trending?api_key=KEY&limit=N&rating=g

struct GiphyService: GIFProvider {
    let apiKey: String

    private static let base = "https://api.giphy.com/v1/gifs"

    func search(_ query: String, limit: Int = 9, offset: Int = 0) async throws -> [GIFResult] {
        guard !apiKey.isEmpty else { throw GIFError.missingAPIKey }
        let url = try buildURL(path: "search", extra: [
            "q":      query,
            "offset": "\(offset)",
            "lang":   "en",
        ], limit: limit)
        let response: GiphyResponse = try await URLSession.shared.fetchJSON(url)
        return response.data.compactMap(\.gifResult)
    }

    func trending(limit: Int = 9) async throws -> [GIFResult] {
        guard !apiKey.isEmpty else { throw GIFError.missingAPIKey }
        let url = try buildURL(path: "trending", extra: [:], limit: limit)
        let response: GiphyResponse = try await URLSession.shared.fetchJSON(url)
        return response.data.compactMap(\.gifResult)
    }

    // MARK: - Private

    private func buildURL(path: String, extra: [String: String], limit: Int) throws -> URL {
        var comps = URLComponents(string: "\(Self.base)/\(path)")!
        var items: [URLQueryItem] = [
            .init(name: "api_key", value: apiKey),
            .init(name: "limit",   value: "\(limit)"),
            .init(name: "rating",  value: "g"),
        ]
        items += extra.map { URLQueryItem(name: $0.key, value: $0.value) }
        comps.queryItems = items
        guard let url = comps.url else { throw URLError(.badURL) }
        return url
    }
}

// MARK: - Codable response models

private struct GiphyResponse: Decodable {
    let data: [GiphyGIF]
}

private struct GiphyGIF: Decodable {
    let id: String
    let images: GiphyImages

    var gifResult: GIFResult? {
        guard
            let previewURL = URL(string: images.fixedWidthSmall.webp ?? images.fixedWidthSmall.url),
            let fullURL    = URL(string: images.original.webp ?? images.original.url)
        else { return nil }
        let w = Int(images.fixedWidthSmall.width) ?? 200
        let h = Int(images.fixedWidthSmall.height) ?? 150
        return GIFResult(id: id, previewURL: previewURL, fullURL: fullURL, width: w, height: h)
    }
}

private struct GiphyImages: Decodable {
    let fixedWidthSmall: GiphyRendition
    let original: GiphyRendition

    enum CodingKeys: String, CodingKey {
        case fixedWidthSmall = "fixed_width_small"
        case original
    }
}

private struct GiphyRendition: Decodable {
    let url: String
    let webp: String?
    let width: String
    let height: String
}

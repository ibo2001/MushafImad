import Foundation

actor ItqanAPIClient {
    private struct CacheEntry: Sendable {
        let data: Data
        let expiresAt: Date
    }

    private let baseURL: URL
    private let session: URLSession
    private let ttl: TimeInterval
    private var responseCache: [String: CacheEntry] = [:]

    init(
        baseURL: URL = URL(string: "https://api.cms.itqan.dev")!,
        session: URLSession = .shared,
        ttl: TimeInterval = 30 * 60
    ) {
        self.baseURL = baseURL
        self.session = session
        self.ttl = ttl
    }

    func fetchReciters() async throws -> [ItqanReciter] {
        try await request(path: "/reciters/", query: [], responseType: ItqanPaginatedResponse<ItqanReciter>.self).results
    }

    func fetchRecitationAssets(reciterId: Int, riwayahId: Int = 1) async throws -> [ItqanRecitationAsset] {
        try await request(
            path: "/recitations/",
            query: [
                URLQueryItem(name: "reciter_id", value: String(reciterId)),
                URLQueryItem(name: "riwayah_id", value: String(riwayahId))
            ],
            responseType: ItqanPaginatedResponse<ItqanRecitationAsset>.self
        ).results
    }

    func fetchSurahTracks(assetId: Int) async throws -> [ItqanSurahTrack] {
        try await request(
            path: "/recitations/\(assetId)/",
            query: [
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "page_size", value: "114")
            ],
            responseType: ItqanPaginatedResponse<ItqanSurahTrack>.self
        ).results
    }

    private func request<T: Decodable>(
        path: String,
        query: [URLQueryItem],
        responseType: T.Type
    ) async throws -> T {
        let request = try buildRequest(path: path, query: query)
        let cacheKey = request.url?.absoluteString ?? path

        if let entry = responseCache[cacheKey], entry.expiresAt > Date() {
            return try decode(responseType, from: entry.data)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw TimingProviderError.invalidResponse
        }

        let decoded = try decode(responseType, from: data)
        responseCache[cacheKey] = CacheEntry(data: data, expiresAt: Date().addingTimeInterval(ttl))
        return decoded
    }

    private func decode<T: Decodable>(_ responseType: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(responseType, from: data)
        } catch {
            throw TimingProviderError.unsupportedSchema
        }
    }

    private func buildRequest(path: String, query: [URLQueryItem]) throws -> URLRequest {
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw TimingProviderError.invalidURL
        }
        components.path = normalizedPath
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else {
            throw TimingProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}

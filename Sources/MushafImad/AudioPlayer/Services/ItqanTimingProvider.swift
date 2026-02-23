import Foundation

/// Adapter that fetches verse timings from the Itqan API.
struct ItqanTimingProvider: VerseTimingProvider {
    private let baseURL: URL
    private let endpointPaths: [String]
    private let session: URLSession

    init(
        baseURL: URL = URL(string: "https://api.cms.itqan.dev")!,
        endpointPaths: [String] = [
            "/api/v1/timings/verses",
            "/api/timings/verses",
            "/timings/verses"
        ],
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.endpointPaths = endpointPaths
        self.session = session
    }

    func fetchTiming(for reciterId: Int, surahId: Int) async throws -> [VerseTiming] {
        for path in endpointPaths {
            do {
                let request = try buildRequest(path: path, reciterId: reciterId, surahId: surahId)
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    continue
                }

                let timings = try parseTimings(from: data, fallbackSurahId: surahId)
                if !timings.isEmpty {
                    return timings.sorted { $0.ayahId < $1.ayahId }
                }
            } catch {
                continue
            }
        }

        throw TimingProviderError.missingData
    }

    private func buildRequest(path: String, reciterId: Int, surahId: Int) throws -> URLRequest {
        let endpoint = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw TimingProviderError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "reciterId", value: String(reciterId)),
            URLQueryItem(name: "reciter_id", value: String(reciterId)),
            URLQueryItem(name: "surahId", value: String(surahId)),
            URLQueryItem(name: "surah_id", value: String(surahId))
        ]

        guard let url = components.url else {
            throw TimingProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12
        return request
    }

    private func parseTimings(from data: Data, fallbackSurahId: Int) throws -> [VerseTiming] {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let entries = extractEntries(from: jsonObject)
        guard !entries.isEmpty else {
            throw TimingProviderError.unsupportedSchema
        }

        let timings = entries.compactMap { entry -> VerseTiming? in
            guard let ayahId = intValue(in: entry, keys: ["ayahId", "ayah_id", "ayah", "aya", "verse", "verse_id", "verseNumber"]) else {
                return nil
            }

            guard let rawStart = doubleValue(in: entry, keys: ["startTime", "start_time", "start", "from"]),
                  let rawEnd = doubleValue(in: entry, keys: ["endTime", "end_time", "end", "to"]) else {
                return nil
            }

            let surahId = intValue(in: entry, keys: ["surahId", "surah_id", "sura", "sura_id", "chapter_id"]) ?? fallbackSurahId
            return VerseTiming(
                surahId: surahId,
                ayahId: ayahId,
                startTime: normalizedTime(rawStart),
                endTime: normalizedTime(rawEnd)
            )
        }

        if timings.isEmpty {
            throw TimingProviderError.unsupportedSchema
        }
        return timings
    }

    private func extractEntries(from object: Any) -> [[String: Any]] {
        if let list = object as? [[String: Any]] {
            return list
        }

        guard let dictionary = object as? [String: Any] else {
            return []
        }

        let candidateKeys = ["data", "result", "results", "timings", "items", "verses", "ayah_timings", "ayahTiming"]
        for key in candidateKeys {
            if let nested = dictionary[key] as? [[String: Any]] {
                return nested
            }
            if let nestedDict = dictionary[key] as? [String: Any],
               let nested = nestedDict["items"] as? [[String: Any]] {
                return nested
            }
        }

        return []
    }

    private func intValue(in dictionary: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = dictionary[key] as? Int { return value }
            if let value = dictionary[key] as? NSNumber { return value.intValue }
            if let value = dictionary[key] as? String, let intValue = Int(value) { return intValue }
        }
        return nil
    }

    private func doubleValue(in dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = dictionary[key] as? Double { return value }
            if let value = dictionary[key] as? Int { return Double(value) }
            if let value = dictionary[key] as? NSNumber { return value.doubleValue }
            if let value = dictionary[key] as? String, let doubleValue = Double(value) { return doubleValue }
        }
        return nil
    }

    private func normalizedTime(_ rawValue: Double) -> TimeInterval {
        // Support both milliseconds and seconds payloads.
        rawValue > 10_000 ? rawValue / 1000.0 : rawValue
    }
}

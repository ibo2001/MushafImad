import Foundation

/// Provider backed by the Itqan API contract (`/recitations/{assetId}/`).
actor ItqanTimingProvider: VerseTimingProvider {
    private let apiClient: ItqanAPIClient
    private var chapterCache: [String: ChapterTimingData] = [:]

    init(apiClient: ItqanAPIClient = ItqanAPIClient()) {
        self.apiClient = apiClient
    }

    func fetchChapterData(for reciterId: Int, surahId: Int) async throws -> ChapterTimingData {
        guard let assetId = ReciterDataProvider.itqanAssetId(for: reciterId) else {
            throw TimingProviderError.unsupportedTimingSource
        }

        let cacheKey = "\(assetId)-\(surahId)"
        if let cached = chapterCache[cacheKey] {
            if cached.timings.isEmpty {
                throw TimingProviderError.missingData
            }
            return cached
        }

        let tracks = try await apiClient.fetchSurahTracks(assetId: assetId)
        guard let track = tracks.first(where: { $0.surahNumber == surahId }) else {
            chapterCache[cacheKey] = ChapterTimingData(timings: [], audioURL: nil)
            throw TimingProviderError.missingData
        }

        let timings = track.ayahsTimings.compactMap { timing -> VerseTiming? in
            let parts = timing.ayahKey.split(separator: ":")
            guard parts.count == 2,
                  let trackSurahId = Int(parts[0]),
                  let ayahId = Int(parts[1]) else {
                return nil
            }

            return VerseTiming(
                surahId: trackSurahId,
                ayahId: ayahId,
                startTime: Double(timing.startMs) / 1000.0,
                endTime: Double(timing.endMs) / 1000.0
            )
        }
        .sorted { $0.ayahId < $1.ayahId }

        let chapterData = ChapterTimingData(timings: timings, audioURL: track.audioURL)
        chapterCache[cacheKey] = chapterData

        if timings.isEmpty {
            throw TimingProviderError.missingData
        }
        return chapterData
    }
}

import Foundation

/// Coordinates timing retrieval based on the reciter timing source.
public actor TimingManager {
    private let itqanProvider: VerseTimingProvider
    private let mp3Provider: VerseTimingProvider
    private let timingSourceResolver: @Sendable (Int) -> TimingSource

    public init() {
        self.itqanProvider = ItqanTimingProvider()
        self.mp3Provider = Mp3QuranTimingProvider()
        self.timingSourceResolver = { ReciterDataProvider.timingSource(for: $0) }
    }

    init(
        itqanProvider: VerseTimingProvider,
        mp3Provider: VerseTimingProvider,
        timingSourceResolver: @escaping @Sendable (Int) -> TimingSource
    ) {
        self.itqanProvider = itqanProvider
        self.mp3Provider = mp3Provider
        self.timingSourceResolver = timingSourceResolver
    }

    public func timingSource(for reciterId: Int) -> TimingSource {
        timingSourceResolver(reciterId)
    }

    public func getChapterDataForPlayback(reciterId: Int, surahId: Int) async throws -> ChapterTimingData {
        switch timingSourceResolver(reciterId) {
        case .mp3quran:
            return try await mp3Provider.fetchChapterData(for: reciterId, surahId: surahId)
        case .itqan:
            return try await itqanProvider.fetchChapterData(for: reciterId, surahId: surahId)
        case .both:
            do {
                return try await mp3Provider.fetchChapterData(for: reciterId, surahId: surahId)
            } catch {
                AppLogger.shared.warn(
                    "TimingManager: MP3Quran data unavailable for reciter \(reciterId), surah \(surahId). Falling back to Itqan.",
                    category: .network
                )
                return try await itqanProvider.fetchChapterData(for: reciterId, surahId: surahId)
            }
        case .none:
            throw TimingProviderError.unsupportedTimingSource
        }
    }

    public func refreshRemoteTimingIfAvailable(reciterId: Int, surahId: Int) async throws -> ChapterTimingData? {
        switch timingSourceResolver(reciterId) {
        case .both, .itqan:
            return try await itqanProvider.fetchChapterData(for: reciterId, surahId: surahId)
        case .mp3quran, .none:
            return nil
        }
    }
}

import Foundation

/// Internal provider contract for verse timing data sources.
protocol VerseTimingProvider: Sendable {
    func fetchChapterData(for reciterId: Int, surahId: Int) async throws -> ChapterTimingData
}

/// Canonical chapter timing payload used by all timing providers.
struct ChapterTimingData: Equatable, Sendable {
    let timings: [VerseTiming]
    let audioURL: URL?
}

public enum TimingProviderError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case missingData
    case unsupportedSchema
    case unsupportedTimingSource
}

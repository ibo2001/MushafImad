import Foundation

/// Internal provider contract for verse timing data sources.
protocol VerseTimingProvider: Sendable {
    func fetchChapterData(for reciterId: Int, surahId: Int) async throws -> ChapterTimingData
}

/// Canonical chapter timing payload used by all timing providers.
public struct ChapterTimingData: Equatable, Sendable {
    public let timings: [VerseTiming]
    public let audioURL: URL?

    public init(timings: [VerseTiming], audioURL: URL?) {
        self.timings = timings
        self.audioURL = audioURL
    }
}

public enum TimingProviderError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case missingData
    case unsupportedSchema
    case unsupportedTimingSource
}

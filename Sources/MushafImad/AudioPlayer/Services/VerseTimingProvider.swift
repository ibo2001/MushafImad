import Foundation

/// Internal provider contract for verse timing data sources.
protocol VerseTimingProvider: Sendable {
    func fetchTiming(for reciterId: Int, surahId: Int) async throws -> [VerseTiming]
}

enum TimingProviderError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case missingData
    case unsupportedSchema
}

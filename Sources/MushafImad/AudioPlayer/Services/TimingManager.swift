import Foundation

/// Coordinates multi-source timing retrieval with Itqan-first fallback behavior.
public actor TimingManager {
    private let primaryProvider: VerseTimingProvider
    private let fallbackProvider: VerseTimingProvider

    public init() {
        self.primaryProvider = ItqanTimingProvider()
        self.fallbackProvider = Mp3QuranTimingProvider()
    }

    init(primaryProvider: VerseTimingProvider, fallbackProvider: VerseTimingProvider) {
        self.primaryProvider = primaryProvider
        self.fallbackProvider = fallbackProvider
    }

    /// Attempts Itqan first, then falls back to MP3Quran if needed.
    public func getTiming(reciterId: Int, surahId: Int) async throws -> [VerseTiming] {
        do {
            let primary = try await primaryProvider.fetchTiming(for: reciterId, surahId: surahId)
            if !primary.isEmpty {
                return primary
            }
        } catch {
            AppLogger.shared.warn(
                "TimingManager: Itqan provider failed for reciter \(reciterId), surah \(surahId): \(error.localizedDescription). Falling back to MP3Quran.",
                category: .network
            )
        }

        let fallback = try await fallbackProvider.fetchTiming(for: reciterId, surahId: surahId)
        guard !fallback.isEmpty else {
            throw TimingProviderError.missingData
        }
        return fallback
    }
}

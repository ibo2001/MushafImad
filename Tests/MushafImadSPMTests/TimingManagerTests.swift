import Foundation
import Testing
@testable import MushafImad

private struct MockTimingProvider: VerseTimingProvider {
    enum Behavior {
        case success(ChapterTimingData)
        case failure(MockTimingError)
    }

    let behavior: Behavior

    func fetchChapterData(for reciterId: Int, surahId: Int) async throws -> ChapterTimingData {
        switch behavior {
        case let .success(data):
            return data
        case let .failure(error):
            throw error
        }
    }
}

private enum MockTimingError: Error {
    case forcedFailure
}

@Test func timingManagerReturnsPrimaryWhenAvailable() async throws {
    let primaryTiming = [VerseTiming(surahId: 1, ayahId: 1, startTime: 0, endTime: 2)]
    let primaryData = ChapterTimingData(timings: primaryTiming, audioURL: nil)
    let manager = TimingManager(
        itqanProvider: MockTimingProvider(behavior: .failure(.forcedFailure)),
        mp3Provider: MockTimingProvider(behavior: .success(primaryData)),
        timingSourceResolver: { _ in .mp3quran }
    )

    let result = try await manager.getChapterDataForPlayback(reciterId: 1, surahId: 1)
    #expect(result.timings == primaryTiming)
}

@Test func timingManagerFallsBackWhenPrimaryFails() async throws {
    let fallbackTiming = [VerseTiming(surahId: 1, ayahId: 2, startTime: 2, endTime: 4)]
    let fallbackData = ChapterTimingData(timings: fallbackTiming, audioURL: nil)
    let manager = TimingManager(
        itqanProvider: MockTimingProvider(behavior: .success(fallbackData)),
        mp3Provider: MockTimingProvider(behavior: .failure(MockTimingError.forcedFailure)),
        timingSourceResolver: { _ in .both(itqanAssetId: 11) }
    )

    let result = try await manager.getChapterDataForPlayback(reciterId: 1, surahId: 1)
    #expect(result.timings == fallbackTiming)
}

@Test func timingManagerReturnsItqanForItqanOnlySource() async throws {
    let itqanTiming = [VerseTiming(surahId: 1, ayahId: 3, startTime: 4, endTime: 6)]
    let itqanData = ChapterTimingData(timings: itqanTiming, audioURL: URL(string: "https://itqan.example/001.mp3"))
    let manager = TimingManager(
        itqanProvider: MockTimingProvider(behavior: .success(itqanData)),
        mp3Provider: MockTimingProvider(behavior: .success(ChapterTimingData(timings: [], audioURL: nil))),
        timingSourceResolver: { _ in .itqan(assetId: 11) }
    )

    let result = try await manager.getChapterDataForPlayback(reciterId: 1001, surahId: 1)
    #expect(result.timings == itqanTiming)
    #expect(result.audioURL == URL(string: "https://itqan.example/001.mp3"))
}

@Test func timingManagerThrowsWhenBothSourcesFail() async {
    let manager = TimingManager(
        itqanProvider: MockTimingProvider(behavior: .failure(MockTimingError.forcedFailure)),
        mp3Provider: MockTimingProvider(behavior: .failure(MockTimingError.forcedFailure)),
        timingSourceResolver: { _ in .both(itqanAssetId: 11) }
    )

    await #expect(throws: MockTimingError.self) {
        _ = try await manager.getChapterDataForPlayback(reciterId: 1, surahId: 1)
    }
}

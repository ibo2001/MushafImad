import Foundation
import Testing
@testable import MushafImad

private struct MockTimingProvider: VerseTimingProvider {
    enum Behavior {
        case success([VerseTiming])
        case failure(MockTimingError)
    }

    let behavior: Behavior

    func fetchTiming(for reciterId: Int, surahId: Int) async throws -> [VerseTiming] {
        switch behavior {
        case let .success(timings):
            return timings
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
    let manager = TimingManager(
        primaryProvider: MockTimingProvider(behavior: .success(primaryTiming)),
        fallbackProvider: MockTimingProvider(behavior: .failure(MockTimingError.forcedFailure))
    )

    let result = try await manager.getTiming(reciterId: 1, surahId: 1)
    #expect(result == primaryTiming)
}

@Test func timingManagerFallsBackWhenPrimaryFails() async throws {
    let fallbackTiming = [VerseTiming(surahId: 1, ayahId: 2, startTime: 2, endTime: 4)]
    let manager = TimingManager(
        primaryProvider: MockTimingProvider(behavior: .failure(MockTimingError.forcedFailure)),
        fallbackProvider: MockTimingProvider(behavior: .success(fallbackTiming))
    )

    let result = try await manager.getTiming(reciterId: 1, surahId: 1)
    #expect(result == fallbackTiming)
}

@Test func timingManagerFallsBackWhenPrimaryIsEmpty() async throws {
    let fallbackTiming = [VerseTiming(surahId: 1, ayahId: 3, startTime: 4, endTime: 6)]
    let manager = TimingManager(
        primaryProvider: MockTimingProvider(behavior: .success([])),
        fallbackProvider: MockTimingProvider(behavior: .success(fallbackTiming))
    )

    let result = try await manager.getTiming(reciterId: 1, surahId: 1)
    #expect(result == fallbackTiming)
}

@Test func timingManagerThrowsWhenBothSourcesFail() async {
    let manager = TimingManager(
        primaryProvider: MockTimingProvider(behavior: .failure(MockTimingError.forcedFailure)),
        fallbackProvider: MockTimingProvider(behavior: .failure(MockTimingError.forcedFailure))
    )

    await #expect(throws: MockTimingError.self) {
        _ = try await manager.getTiming(reciterId: 1, surahId: 1)
    }
}

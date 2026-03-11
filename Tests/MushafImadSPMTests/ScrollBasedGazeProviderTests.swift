import Foundation
import Testing
@testable import MushafImad

@Test @MainActor func scrollProviderIsAlwaysAvailable() {
    let provider = ScrollBasedGazeProvider()
    #expect(provider.isAvailable)
}

@Test @MainActor func scrollProviderStartsWithNilGaze() {
    let provider = ScrollBasedGazeProvider()
    #expect(provider.latestGazePoint == nil)
}

@Test @MainActor func scrollProviderProducesGazeOnStart() {
    let provider = ScrollBasedGazeProvider()
    provider.startTracking()
    #expect(provider.latestGazePoint != nil)
    provider.stopTracking()
}

@Test @MainActor func scrollProviderClearsGazeOnStop() {
    let provider = ScrollBasedGazeProvider()
    provider.startTracking()
    provider.stopTracking()
    #expect(provider.latestGazePoint == nil)
}

@Test @MainActor func scrollProviderInitialGazeIsTopRight() {
    let provider = ScrollBasedGazeProvider()
    provider.startTracking()
    guard let point = provider.latestGazePoint else {
        Issue.record("Expected a gaze point after starting")
        return
    }
    // Arabic reads RTL, so initial position should be near x=1.0 (right)
    #expect(point.x > 0.5)
    // Initial position should be near top of page
    #expect(point.y < 0.2)
    provider.stopTracking()
}

@Test @MainActor func scrollProviderConfidenceIsBelowOne() {
    let provider = ScrollBasedGazeProvider()
    provider.startTracking()
    guard let point = provider.latestGazePoint else {
        Issue.record("Expected a gaze point")
        return
    }
    #expect(point.confidence < 1.0)
    provider.stopTracking()
}

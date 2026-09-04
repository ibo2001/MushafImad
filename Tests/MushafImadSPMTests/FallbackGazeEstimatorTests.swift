import Foundation
import Testing
import CoreGraphics
@testable import MushafImad

/// Tests for FallbackGazeEstimator to ensure heuristic estimation logic,
/// scroll position tracking, and confidence calculation work correctly.
@Suite(.serialized)
@MainActor
struct FallbackGazeEstimatorTests {

    // MARK: - Helpers

    /// Reads the estimator's current gaze, waiting a little longer if the update
    /// timer has not fired yet.
    ///
    /// `startForPage` drives updates from a 0.25s `Timer` on `RunLoop.main`, and the
    /// timer body hops onto the main actor again before `estimatedGaze` is assigned.
    /// A fixed `Task.sleep` gives both hops exactly one chance to land, which is
    /// enough on a quiet machine and not enough on a loaded CI runner — there the
    /// gaze came back nil, and the force-unwrap that followed trapped and took the
    /// whole test process down with it.
    ///
    /// Polling costs nothing when the timer has already fired: the common path
    /// returns immediately and the surrounding sleeps keep their original timing.
    private func waitForGaze(
        from estimator: FallbackGazeEstimator,
        timeout: TimeInterval = 2
    ) async -> GazePoint? {
        if let gaze = estimator.estimatedGaze { return gaze }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
            if let gaze = estimator.estimatedGaze { return gaze }
        }
        return nil
    }

    // MARK: - Initialization Tests
    
    @Test
    func testInitialState() async {
        // Arrange & Act
        let estimator = FallbackGazeEstimator()
        
        // Assert
        #expect(estimator.estimatedGaze == nil)
        #expect(estimator.isActive == false)
        #expect(estimator.arabicWordsPerMinute == 80)
        #expect(estimator.wordsPerLine == 10)
        #expect(estimator.linesPerPage == 15)
    }
    
    @Test
    func testDefaultConfiguration() async {
        // Arrange & Act
        let estimator = FallbackGazeEstimator()
        
        // Assert - default reading speed should be reasonable for Arabic Quran reading
        #expect(estimator.arabicWordsPerMinute >= 50)
        #expect(estimator.arabicWordsPerMinute <= 120)
    }
    
    // MARK: - Start/Stop Tests
    
    @Test
    func testStartForPageActivatesEstimator() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        
        // Assert
        #expect(estimator.isActive == true)
    }
    
    @Test
    func testStopEstimatingDeactivates() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        estimator.startForPage(pageFrame: pageFrame)
        
        // Act
        estimator.stopEstimating()
        
        // Assert
        #expect(estimator.isActive == false)
        #expect(estimator.estimatedGaze == nil)
    }
    
    @Test
    func testStartWhileActiveStopsFirst() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        let frame1 = CGRect(x: 0, y: 0, width: 375, height: 812)
        let frame2 = CGRect(x: 0, y: 0, width: 812, height: 375)
        
        estimator.startForPage(pageFrame: frame1)
        
        // Act
        estimator.startForPage(pageFrame: frame2)
        
        // Assert
        #expect(estimator.isActive == true)
    }
    
    // MARK: - Gaze Estimation Tests
    
    @Test
    func testEstimatedGazeGeneratedAfterStart() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        
        // Wait for timer to fire
        try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds

        // Assert
        #expect(await waitForGaze(from: estimator) != nil)
    }
    
    @Test
    func testEstimatedGazeStartsAtTopOfPage() async throws {
        // Arrange
        let estimator = FallbackGazeEstimator()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Assert
        let gaze = try #require(await waitForGaze(from: estimator))
        // Y position should be near the top (first line)
        #expect(gaze.screenPosition.y < 200)
    }
    
    @Test
    func testEstimatedGazeProgressesOverTime() async throws {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 600  // Very fast for testing
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        let firstGaze = try #require(await waitForGaze(from: estimator))

        // Wait past one full line: secondsPerLine is 600 / WPM (1.0 s at 600),
        // plus slack so CI scheduling delay cannot leave both samples on line 0.
        let lineTime = 600.0 / estimator.arabicWordsPerMinute
        try? await Task.sleep(nanoseconds: UInt64((lineTime + 0.2) * 1_000_000_000))
        let secondGaze = try #require(await waitForGaze(from: estimator))

        // Assert - Y position should increase (moving down the page)
        #expect(secondGaze.screenPosition.y > firstGaze.screenPosition.y)
    }
    
    @Test
    func testEstimatedGazeRTLDirection() async throws {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 600  // Fast for testing
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        let firstGaze = try #require(await waitForGaze(from: estimator))

        try? await Task.sleep(nanoseconds: 200_000_000)
        let secondGaze = try #require(await waitForGaze(from: estimator))

        // Assert - X position should decrease (RTL: moving from right to left)
        // Within same line, X should move left (decrease)
        if firstGaze.screenPosition.y == secondGaze.screenPosition.y {
            #expect(secondGaze.screenPosition.x <= firstGaze.screenPosition.x)
        }
    }
    
    // MARK: - Reading Speed Configuration Tests
    
    @Test
    func testChangingReadingSpeedAffectsEstimation() async throws {
        // Arrange
        let estimator = FallbackGazeEstimator()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let slowWPM = 40.0
        let fastWPM = 200.0
        // Sample after the fast rate has crossed a line (600 / 200 = 3 s) but
        // long before the slow rate does (600 / 40 = 15 s).
        let waitNanoseconds = UInt64((600.0 / fastWPM + 1.0) * 1_000_000_000)
        
        // Test with slow reading speed
        estimator.arabicWordsPerMinute = slowWPM
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: waitNanoseconds)
        let slowGaze = try #require(await waitForGaze(from: estimator))
        estimator.stopEstimating()

        // Test with fast reading speed
        estimator.arabicWordsPerMinute = fastWPM
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: waitNanoseconds)
        let fastGaze = try #require(await waitForGaze(from: estimator))

        // Assert - faster reading should progress further down the page
        #expect(fastGaze.screenPosition.y > slowGaze.screenPosition.y)
    }
    
    @Test
    func testWordsPerLineConfiguration() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        
        // Act
        estimator.wordsPerLine = 12
        
        // Assert
        #expect(estimator.wordsPerLine == 12)
    }
    
    // MARK: - Pause/Resume Tests
    
    @Test
    func testPauseStopsProgressionTemporarily() async throws {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 600  // Fast for testing
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        let beforePause = try #require(await waitForGaze(from: estimator))

        estimator.pause()
        try? await Task.sleep(nanoseconds: 500_000_000)  // Paused for 0.5s
        let duringPause = try #require(await waitForGaze(from: estimator))

        // Assert - position should not change significantly during pause
        // Allow small difference due to timer updates
        let yDiff = abs(duringPause.screenPosition.y - beforePause.screenPosition.y)
        #expect(yDiff < 50)  // Should be minimal movement
    }
    
    @Test
    func testResumeAfterPauseContinuesProgression() async throws {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 600
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        estimator.pause()
        try? await Task.sleep(nanoseconds: 300_000_000)
        estimator.resume()
        
        let afterResume = try #require(await waitForGaze(from: estimator))
        // Wait past one full line (600 / WPM + slack), as above.
        let lineTime = 600.0 / estimator.arabicWordsPerMinute
        try? await Task.sleep(nanoseconds: UInt64((lineTime + 0.2) * 1_000_000_000))
        let afterMoreTime = try #require(await waitForGaze(from: estimator))

        // Assert - should continue progressing after resume
        #expect(afterMoreTime.screenPosition.y > afterResume.screenPosition.y)
    }
    
    @Test
    func testMultiplePauseResumeCycles() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 600
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // First pause/resume
        estimator.pause()
        try? await Task.sleep(nanoseconds: 200_000_000)
        estimator.resume()
        
        // Second pause/resume
        estimator.pause()
        try? await Task.sleep(nanoseconds: 200_000_000)
        estimator.resume()
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Assert - should still be generating estimates
        #expect(await waitForGaze(from: estimator) != nil)
        #expect(estimator.isActive == true)
    }

    @Test
    func testPauseWhenNotActiveDoesNothing() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        
        // Act & Assert - should not crash
        estimator.pause()
        estimator.resume()
    }
    
    // MARK: - Reset Timer Tests
    
    @Test
    func testResetPageTimerRestartsFromBeginning() async throws {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 600
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        // Settle past the first line (600 / WPM = 1.0 s at 600, plus slack)
        // so the pre-reset sample is genuinely below the post-reset one.
        let lineTime = 600.0 / estimator.arabicWordsPerMinute
        try? await Task.sleep(nanoseconds: UInt64((lineTime + 0.5) * 1_000_000_000))
        let beforeReset = try #require(await waitForGaze(from: estimator))

        estimator.resetPageTimer()
        try? await Task.sleep(nanoseconds: 300_000_000)
        let afterReset = try #require(await waitForGaze(from: estimator))

        // Assert - after reset, should be back near the top
        #expect(afterReset.screenPosition.y < beforeReset.screenPosition.y)
    }
    
    // MARK: - Confidence Calculation Tests
    
    @Test
    func testConfidenceDecreasesOverTime() async throws {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 80  // Normal speed
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        let earlyConfidence = try #require(await waitForGaze(from: estimator)).confidence

        try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 more seconds
        let laterConfidence = try #require(await waitForGaze(from: estimator)).confidence

        // Assert - confidence should decrease over time
        #expect(laterConfidence < earlyConfidence)
    }
    
    @Test
    func testConfidenceHasMinimumValue() async throws {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 600  // Fast to reach end quickly
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
        
        // Assert - confidence should not go below minimum (0.3)
        let confidence = try #require(await waitForGaze(from: estimator)).confidence
        #expect(confidence >= 0.3)
    }
    
    // MARK: - Geometry Update Tests
    
    @Test
    func testUpdateGeometryDuringEstimation() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        let portraitFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        estimator.startForPage(pageFrame: portraitFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Act - rotate to landscape
        let landscapeFrame = CGRect(x: 0, y: 0, width: 812, height: 375)
        estimator.updateGeometry(frame: landscapeFrame)
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Assert - should still be generating estimates with new geometry
        #expect(await waitForGaze(from: estimator) != nil)
        #expect(estimator.isActive == true)
    }
    
    // MARK: - Edge Cases
    
    @Test
    func testStopWhenNotActiveDoesNotCrash() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        
        // Act & Assert - should not crash
        estimator.stopEstimating()
        #expect(estimator.isActive == false)
    }
    
    @Test
    func testZeroWidthFrameDoesNotCrash() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        let zeroFrame = CGRect(x: 0, y: 0, width: 0, height: 812)
        
        // Act & Assert - should not crash
        estimator.startForPage(pageFrame: zeroFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Estimator should handle gracefully
        #expect(estimator.isActive == true)
    }
    
    @Test
    func testEstimationDoesNotExceedPageBounds() async throws {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 1200  // Very fast
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds - should finish page
        
        // Assert - should clamp to last line
        let gaze = try #require(await waitForGaze(from: estimator))
        // Y should not exceed page bounds
        #expect(gaze.screenPosition.y <= pageFrame.maxY)
    }
    
    @Test
    func testNegativeTimeHandledGracefully() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act - start, pause immediately, then resume
        estimator.startForPage(pageFrame: pageFrame)
        estimator.pause()
        estimator.resume()
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Assert - should handle edge case without crashing
        #expect(await waitForGaze(from: estimator) != nil)
    }
}

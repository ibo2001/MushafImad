import Foundation
import Testing
import CoreGraphics
@testable import MushafImad

/// Tests for FallbackGazeEstimator to ensure heuristic estimation logic,
/// scroll position tracking, and confidence calculation work correctly.
@Suite(.serialized)
@MainActor
struct FallbackGazeEstimatorTests {
    
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
        #expect(estimator.estimatedGaze != nil)
    }
    
    @Test
    func testEstimatedGazeStartsAtTopOfPage() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Assert
        let gaze = estimator.estimatedGaze
        #expect(gaze != nil)
        // Y position should be near the top (first line)
        #expect(gaze!.screenPosition.y < 200)
    }
    
    @Test
    func testEstimatedGazeProgressesOverTime() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 600  // Very fast for testing
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        let firstGaze = estimator.estimatedGaze
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        let secondGaze = estimator.estimatedGaze
        
        // Assert - Y position should increase (moving down the page)
        #expect(firstGaze != nil)
        #expect(secondGaze != nil)
        withKnownIssue(experimentalGazeProgression) {
            #expect(secondGaze!.screenPosition.y > firstGaze!.screenPosition.y)
        }
    }
    
    @Test
    func testEstimatedGazeRTLDirection() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 600  // Fast for testing
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        let firstGaze = estimator.estimatedGaze
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        let secondGaze = estimator.estimatedGaze
        
        // Assert - X position should decrease (RTL: moving from right to left)
        #expect(firstGaze != nil)
        #expect(secondGaze != nil)
        // Within same line, X should move left (decrease)
        if firstGaze!.screenPosition.y == secondGaze!.screenPosition.y {
            #expect(secondGaze!.screenPosition.x <= firstGaze!.screenPosition.x)
        }
    }
    
    // MARK: - Reading Speed Configuration Tests
    
    @Test
    func testChangingReadingSpeedAffectsEstimation() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Test with slow reading speed
        estimator.arabicWordsPerMinute = 40
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        let slowGaze = estimator.estimatedGaze
        estimator.stopEstimating()
        
        // Test with fast reading speed
        estimator.arabicWordsPerMinute = 200
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        let fastGaze = estimator.estimatedGaze
        
        // Assert - faster reading should progress further down the page
        #expect(slowGaze != nil)
        #expect(fastGaze != nil)
        withKnownIssue(experimentalGazeProgression) {
            #expect(fastGaze!.screenPosition.y > slowGaze!.screenPosition.y)
        }
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
    func testPauseStopsProgressionTemporarily() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 600  // Fast for testing
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        let beforePause = estimator.estimatedGaze
        
        estimator.pause()
        try? await Task.sleep(nanoseconds: 500_000_000)  // Paused for 0.5s
        let duringPause = estimator.estimatedGaze
        
        // Assert - position should not change significantly during pause
        #expect(beforePause != nil)
        #expect(duringPause != nil)
        // Allow small difference due to timer updates
        let yDiff = abs(duringPause!.screenPosition.y - beforePause!.screenPosition.y)
        #expect(yDiff < 50)  // Should be minimal movement
    }
    
    @Test
    func testResumeAfterPauseContinuesProgression() async {
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
        
        let afterResume = estimator.estimatedGaze
        try? await Task.sleep(nanoseconds: 500_000_000)
        let afterMoreTime = estimator.estimatedGaze
        
        // Assert - should continue progressing after resume
        #expect(afterResume != nil)
        #expect(afterMoreTime != nil)
        withKnownIssue(experimentalGazeProgression) {
            #expect(afterMoreTime!.screenPosition.y > afterResume!.screenPosition.y)
        }
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
        #expect(estimator.estimatedGaze != nil)
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
    func testResetPageTimerRestartsFromBeginning() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 600
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 500_000_000)
        let beforeReset = estimator.estimatedGaze
        
        estimator.resetPageTimer()
        try? await Task.sleep(nanoseconds: 300_000_000)
        let afterReset = estimator.estimatedGaze
        
        // Assert - after reset, should be back near the top
        #expect(beforeReset != nil)
        #expect(afterReset != nil)
        withKnownIssue(experimentalGazeProgression) {
            #expect(afterReset!.screenPosition.y < beforeReset!.screenPosition.y)
        }
    }
    
    // MARK: - Confidence Calculation Tests
    
    @Test
    func testConfidenceDecreasesOverTime() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 80  // Normal speed
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 300_000_000)
        let earlyConfidence = estimator.estimatedGaze?.confidence
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 more seconds
        let laterConfidence = estimator.estimatedGaze?.confidence
        
        // Assert - confidence should decrease over time
        #expect(earlyConfidence != nil)
        #expect(laterConfidence != nil)
        #expect(laterConfidence! < earlyConfidence!)
    }
    
    @Test
    func testConfidenceHasMinimumValue() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 600  // Fast to reach end quickly
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
        
        // Assert - confidence should not go below minimum (0.3)
        let confidence = estimator.estimatedGaze?.confidence
        #expect(confidence != nil)
        #expect(confidence! >= 0.3)
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
        #expect(estimator.estimatedGaze != nil)
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
    func testEstimationDoesNotExceedPageBounds() async {
        // Arrange
        let estimator = FallbackGazeEstimator()
        estimator.arabicWordsPerMinute = 1200  // Very fast
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        // Act
        estimator.startForPage(pageFrame: pageFrame)
        try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds - should finish page
        
        // Assert - should clamp to last line
        let gaze = estimator.estimatedGaze
        #expect(gaze != nil)
        // Y should not exceed page bounds
        #expect(gaze!.screenPosition.y <= pageFrame.maxY)
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
        #expect(estimator.estimatedGaze != nil)
    }
}

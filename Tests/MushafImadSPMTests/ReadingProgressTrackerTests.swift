import Foundation
import Testing
import CoreGraphics
import QuartzCore
@testable import MushafImad

/// Tests for ReadingProgressTracker to ensure dwell time detection, progress state transitions,
/// and session tracking work correctly.
@Suite(.serialized)
@MainActor
struct ReadingProgressTrackerTests {
    
    // MARK: - Test Helpers
    
    /// Create a mock verse with highlights
    private func makeMockVerse(
        id: Int,
        chapterNumber: Int = 1,
        number: Int,
        highlights: [(line: Int, left: Float, right: Float)]
    ) -> Verse {
        let verse = Verse()
        verse.verseID = id
        // `chapterNumber` is derived from the linked chapter, so link one rather
        // than assigning it directly.
        let chapter = Chapter()
        chapter.number = chapterNumber
        verse.chapter = chapter
        verse.number = number
        verse.text = "Mock verse \(number)"
        
        for highlight in highlights {
            let h = VerseHighlight()
            h.line = highlight.line
            h.left = highlight.left
            h.right = highlight.right
            verse.highlights1441.append(h)
        }
        
        return verse
    }
    
    /// Create a mock gaze point
    private func makeGazePoint(
        x: CGFloat,
        y: CGFloat,
        confidence: Float = 0.9
    ) -> GazePoint {
        return GazePoint(
            screenPosition: CGPoint(x: x, y: y),
            confidence: confidence,
            timestamp: CACurrentMediaTime()
        )
    }
    
    /// Calculate Y position for a specific line
    private func yPositionForLine(
        _ lineIndex: Int,
        pageWidth: CGFloat,
        headerOffset: CGFloat
    ) -> CGFloat {
        let lineHeight = (pageWidth / 1440.0 * 232.0) * 0.73
        return headerOffset + lineHeight * (CGFloat(lineIndex) + 0.5)
    }
    
    // MARK: - Initialization Tests
    
    @Test
    func testInitialState() async {
        // Arrange & Act
        let tracker = ReadingProgressTracker()
        
        // Assert
        #expect(tracker.activeVerse == nil)
        #expect(tracker.activeLineIndex == 0)
        #expect(tracker.pageCompleted == false)
        #expect(tracker.readingProgress == 0)
        #expect(tracker.isTracking == false)
        #expect(tracker.currentSession == nil)
    }
    
    @Test
    func testDefaultConfiguration() async {
        // Arrange & Act
        let tracker = ReadingProgressTracker()
        
        // Assert
        #expect(tracker.dwellTimeThreshold == 1.5)
        #expect(tracker.pageCompletionDwellTime == 3.0)
        #expect(tracker.autoAdvanceEnabled == true)
    }
    
    // MARK: - Start/Stop Tracking Tests
    
    @Test
    func testStartTrackingSetsInitialState() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verses = [
            makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        ]
        
        // Act
        tracker.startTracking(pageNumber: 1, verses: verses, pageFrame: pageFrame)
        
        // Assert
        #expect(tracker.isTracking == true)
        #expect(tracker.pageCompleted == false)
        #expect(tracker.readingProgress == 0)
        #expect(tracker.activeVerse == nil)
        #expect(tracker.activeLineIndex == 0)
    }
    
    @Test
    func testStopTrackingResetsState() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verses = [
            makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        ]
        
        tracker.startTracking(pageNumber: 1, verses: verses, pageFrame: pageFrame)
        
        // Act
        tracker.stopTracking()
        
        // Assert
        #expect(tracker.isTracking == false)
    }
    
    @Test
    func testStartTrackingWhileAlreadyTrackingStopsFirst() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verses1 = [
            makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        ]
        let verses2 = [
            makeMockVerse(id: 2, number: 2, highlights: [(line: 0, left: 0.0, right: 1.0)])
        ]
        
        tracker.startTracking(pageNumber: 1, verses: verses1, pageFrame: pageFrame)
        
        // Act
        tracker.startTracking(pageNumber: 2, verses: verses2, pageFrame: pageFrame)
        
        // Assert
        #expect(tracker.isTracking == true)
    }
    
    // MARK: - Gaze Processing Tests
    
    @Test
    func testProcessGazePointUpdatesActiveLineIndex() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verses = [
            makeMockVerse(id: 1, number: 1, highlights: [(line: 5, left: 0.0, right: 1.0)])
        ]
        
        tracker.startTracking(pageNumber: 1, verses: verses, pageFrame: pageFrame)
        
        // Create gaze point on line 5
        let gazeY = yPositionForLine(5, pageWidth: 375, headerOffset: 40)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        tracker.processGazePoint(gazePoint)
        
        // Assert
        #expect(tracker.activeLineIndex == 5)
    }
    
    @Test
    func testProcessGazePointUpdatesReadingProgress() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verses = [
            makeMockVerse(id: 1, number: 1, highlights: [(line: 7, left: 0.0, right: 1.0)])
        ]
        
        tracker.startTracking(pageNumber: 1, verses: verses, pageFrame: pageFrame)
        
        // Create gaze point on line 7 (middle of page)
        let gazeY = yPositionForLine(7, pageWidth: 375, headerOffset: 40)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        tracker.processGazePoint(gazePoint)
        
        // Assert
        // Progress should be 7/14 = 0.5
        #expect(tracker.readingProgress == 0.5)
    }
    
    @Test
    func testProcessGazePointOutsidePageDoesNotUpdateState() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verses = [
            makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        ]
        
        tracker.startTracking(pageNumber: 1, verses: verses, pageFrame: pageFrame)
        
        let initialLineIndex = tracker.activeLineIndex
        let initialProgress = tracker.readingProgress
        
        // Create gaze point outside page
        let gazePoint = makeGazePoint(x: 500, y: 100)
        
        // Act
        tracker.processGazePoint(gazePoint)
        
        // Assert - state should remain unchanged
        #expect(tracker.activeLineIndex == initialLineIndex)
        #expect(tracker.readingProgress == initialProgress)
    }
    
    @Test
    func testProcessGazePointWhenNotTrackingDoesNothing() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let gazePoint = makeGazePoint(x: 187.5, y: 100)
        
        // Act
        tracker.processGazePoint(gazePoint)
        
        // Assert
        #expect(tracker.activeLineIndex == 0)
        #expect(tracker.readingProgress == 0)
    }
    
    // MARK: - Dwell Time Detection Tests
    
    @Test
    func testDwellTimeThresholdNotMetDoesNotSetActiveVerse() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        tracker.dwellTimeThreshold = 2.0  // 2 seconds
        
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        tracker.startTracking(pageNumber: 1, verses: [verse], pageFrame: pageFrame)
        
        // Create gaze point on verse
        let gazeY = yPositionForLine(0, pageWidth: 375, headerOffset: 40)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act - process gaze but don't wait for threshold
        tracker.processGazePoint(gazePoint)
        
        // Assert
        #expect(tracker.activeVerse == nil)
    }
    
    @Test
    func testDwellTimeThresholdMetSetsActiveVerse() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        tracker.dwellTimeThreshold = 0.1  // Very short for testing
        
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verse = makeMockVerse(id: 1, chapterNumber: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        tracker.startTracking(pageNumber: 1, verses: [verse], pageFrame: pageFrame)
        
        // Create gaze point on verse
        let gazeY = yPositionForLine(0, pageWidth: 375, headerOffset: 40)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act - process gaze and wait for threshold
        tracker.processGazePoint(gazePoint)
        try? await Task.sleep(nanoseconds: 150_000_000)  // 0.15 seconds
        tracker.processGazePoint(gazePoint)
        
        // Assert
        #expect(tracker.activeVerse?.verseID == 1)
    }
    
    @Test
    func testMovingGazeToDifferentVerseResetsDwellTimer() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        tracker.dwellTimeThreshold = 0.1
        
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verse1 = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        let verse2 = makeMockVerse(id: 2, number: 2, highlights: [(line: 1, left: 0.0, right: 1.0)])
        
        tracker.startTracking(pageNumber: 1, verses: [verse1, verse2], pageFrame: pageFrame)
        
        // Gaze at verse 1
        let gaze1Y = yPositionForLine(0, pageWidth: 375, headerOffset: 40)
        let gaze1 = makeGazePoint(x: 187.5, y: gaze1Y)
        tracker.processGazePoint(gaze1)
        
        try? await Task.sleep(nanoseconds: 50_000_000)  // 0.05 seconds (half threshold)
        
        // Move to verse 2 before threshold met
        let gaze2Y = yPositionForLine(1, pageWidth: 375, headerOffset: 40)
        let gaze2 = makeGazePoint(x: 187.5, y: gaze2Y)
        tracker.processGazePoint(gaze2)
        
        // Assert - active verse should still be nil because dwell was reset
        #expect(tracker.activeVerse == nil)
    }
    
    @Test
    func testActiveVerseChangedCallbackInvoked() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        tracker.dwellTimeThreshold = 0.1
        
        var callbackInvoked = false
        var callbackVerse: Verse?
        
        tracker.onActiveVerseChanged = { verse in
            callbackInvoked = true
            callbackVerse = verse
        }
        
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        tracker.startTracking(pageNumber: 1, verses: [verse], pageFrame: pageFrame)
        
        // Create gaze point on verse
        let gazeY = yPositionForLine(0, pageWidth: 375, headerOffset: 40)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        tracker.processGazePoint(gazePoint)
        try? await Task.sleep(nanoseconds: 150_000_000)
        tracker.processGazePoint(gazePoint)
        
        // Assert
        #expect(callbackInvoked == true)
        #expect(callbackVerse?.verseID == 1)
    }
    
    // MARK: - Page Completion Tests
    
    @Test
    func testPageCompletionNotTriggeredOnEarlyLines() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        tracker.pageCompletionDwellTime = 0.1
        
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 5, left: 0.0, right: 1.0)])
        
        tracker.startTracking(pageNumber: 1, verses: [verse], pageFrame: pageFrame)
        
        // Gaze at line 5 (middle of page)
        let gazeY = yPositionForLine(5, pageWidth: 375, headerOffset: 40)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        tracker.processGazePoint(gazePoint)
        try? await Task.sleep(nanoseconds: 150_000_000)
        tracker.processGazePoint(gazePoint)
        
        // Assert
        #expect(tracker.pageCompleted == false)
    }
    
    @Test
    func testPageCompletionTriggeredOnLastLine() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        tracker.pageCompletionDwellTime = 0.1
        tracker.autoAdvanceEnabled = false  // Disable auto-advance for testing
        
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 14, left: 0.0, right: 1.0)])
        
        tracker.startTracking(pageNumber: 1, verses: [verse], pageFrame: pageFrame)
        
        // Gaze at line 14 (last line)
        let gazeY = yPositionForLine(14, pageWidth: 375, headerOffset: 40)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        tracker.processGazePoint(gazePoint)
        try? await Task.sleep(nanoseconds: 150_000_000)
        tracker.processGazePoint(gazePoint)
        
        // Assert
        #expect(tracker.pageCompleted == true)
        #expect(tracker.readingProgress == 1.0)
    }
    
    @Test
    func testPageCompletionCallbackInvoked() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        tracker.pageCompletionDwellTime = 0.1
        tracker.autoAdvanceEnabled = true
        
        var callbackInvoked = false
        tracker.onPageCompleted = {
            callbackInvoked = true
        }
        
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 14, left: 0.0, right: 1.0)])
        
        tracker.startTracking(pageNumber: 1, verses: [verse], pageFrame: pageFrame)
        
        // Gaze at last line
        let gazeY = yPositionForLine(14, pageWidth: 375, headerOffset: 40)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        tracker.processGazePoint(gazePoint)
        try? await Task.sleep(nanoseconds: 150_000_000)
        tracker.processGazePoint(gazePoint)
        
        // Assert
        #expect(callbackInvoked == true)
    }
    
    @Test
    func testPageCompletionNotInvokedWhenAutoAdvanceDisabled() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        tracker.pageCompletionDwellTime = 0.1
        tracker.autoAdvanceEnabled = false
        
        var callbackInvoked = false
        tracker.onPageCompleted = {
            callbackInvoked = true
        }
        
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 14, left: 0.0, right: 1.0)])
        
        tracker.startTracking(pageNumber: 1, verses: [verse], pageFrame: pageFrame)
        
        // Gaze at last line
        let gazeY = yPositionForLine(14, pageWidth: 375, headerOffset: 40)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        tracker.processGazePoint(gazePoint)
        try? await Task.sleep(nanoseconds: 150_000_000)
        tracker.processGazePoint(gazePoint)
        
        // Assert
        #expect(tracker.pageCompleted == true)
        #expect(callbackInvoked == false)
    }
    
    // MARK: - Pause/Resume Tests
    
    @Test
    func testPauseTrackingRecordsPauseTime() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verses = [
            makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        ]
        
        tracker.startTracking(pageNumber: 1, verses: verses, pageFrame: pageFrame)
        
        // Act
        tracker.pauseTracking()
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        tracker.resumeTracking()
        
        // Assert - session should account for paused time
        tracker.stopTracking()
        #expect(tracker.currentSession != nil)
    }
    
    @Test
    func testPauseWhenNotTrackingDoesNothing() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        
        // Act & Assert - should not crash
        tracker.pauseTracking()
        tracker.resumeTracking()
    }
    
    @Test
    func testMultiplePauseResumeCycles() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verses = [
            makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        ]
        
        tracker.startTracking(pageNumber: 1, verses: verses, pageFrame: pageFrame)
        
        // Act - multiple pause/resume cycles
        tracker.pauseTracking()
        try? await Task.sleep(nanoseconds: 50_000_000)
        tracker.resumeTracking()
        
        tracker.pauseTracking()
        try? await Task.sleep(nanoseconds: 50_000_000)
        tracker.resumeTracking()
        
        // Assert
        tracker.stopTracking()
        #expect(tracker.currentSession != nil)
    }
    
    // MARK: - Session Tracking Tests
    
    @Test
    func testSessionCreatedOnStopTracking() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verse = makeMockVerse(id: 1, chapterNumber: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        tracker.startTracking(pageNumber: 1, verses: [verse], pageFrame: pageFrame)
        
        // Process some gaze points
        let gazeY = yPositionForLine(0, pageWidth: 375, headerOffset: 40)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY, confidence: 0.8)
        tracker.processGazePoint(gazePoint)
        
        // Act
        tracker.stopTracking()
        
        // Assert
        #expect(tracker.currentSession != nil)
        #expect(tracker.currentSession?.pageNumber == 1)
    }
    
    @Test
    func testSessionTracksAverageConfidence() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        tracker.startTracking(pageNumber: 1, verses: [verse], pageFrame: pageFrame)
        
        // Process gaze points with different confidence levels
        let gazeY = yPositionForLine(0, pageWidth: 375, headerOffset: 40)
        tracker.processGazePoint(makeGazePoint(x: 187.5, y: gazeY, confidence: 0.8))
        tracker.processGazePoint(makeGazePoint(x: 187.5, y: gazeY, confidence: 0.6))
        tracker.processGazePoint(makeGazePoint(x: 187.5, y: gazeY, confidence: 1.0))
        
        // Act
        tracker.stopTracking()
        
        // Assert - average should be (0.8 + 0.6 + 1.0) / 3 = 0.8
        #expect(tracker.currentSession?.averageConfidence == 0.8)
    }
    
    @Test
    func testSessionTracksCompletionStatus() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        tracker.pageCompletionDwellTime = 0.1
        tracker.autoAdvanceEnabled = false
        
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 14, left: 0.0, right: 1.0)])
        
        tracker.startTracking(pageNumber: 1, verses: [verse], pageFrame: pageFrame)
        
        // Complete the page
        let gazeY = yPositionForLine(14, pageWidth: 375, headerOffset: 40)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        tracker.processGazePoint(gazePoint)
        try? await Task.sleep(nanoseconds: 150_000_000)
        tracker.processGazePoint(gazePoint)
        
        // Act
        tracker.stopTracking()
        
        // Assert
        #expect(tracker.currentSession?.completedPage == true)
    }
    
    @Test
    func testSessionTracksTrackingMethod() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        tracker.trackingMethod = .heuristic
        
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verses = [
            makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        ]
        
        tracker.startTracking(pageNumber: 1, verses: verses, pageFrame: pageFrame)
        
        // Act
        tracker.stopTracking()
        
        // Assert
        #expect(tracker.currentSession?.trackingMethod == .heuristic)
    }
    
    // MARK: - Geometry Update Tests
    
    @Test
    func testUpdateGeometryAllowsGazeProcessingAfterRotation() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let portraitFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 5, left: 0.0, right: 1.0)])

        tracker.startTracking(pageNumber: 1, verses: [verse], pageFrame: portraitFrame)

        // Rotate to landscape. updateGeometry infers isLandscape from the frame's
        // aspect ratio, so lines now use the 0.7 line-height factor (not portrait's
        // 0.73) and render inside a scroll view taller than the viewport.
        let landscapeFrame = CGRect(x: 0, y: 0, width: 812, height: 375)
        tracker.updateGeometry(frame: landscapeFrame)

        // Line 5's midpoint in content space, then the scroll offset that brings
        // it to the centre of the (shorter) landscape viewport — mirroring what
        // MushafView reports via QuranPageView's onScrollOffsetChange.
        let lineHeight = (812.0 / 1440.0 * 232.0) * 0.7
        let headerOffset: CGFloat = 40 // ReadingProgressTracker's default
        let contentY = headerOffset + lineHeight * 5.5
        let screenY = landscapeFrame.height / 2
        tracker.updateScrollOffset(contentY - screenY)

        let gazePoint = makeGazePoint(x: 406, y: screenY)

        // Act
        tracker.processGazePoint(gazePoint)

        // Assert
        #expect(tracker.activeLineIndex == 5)
    }
    
    // MARK: - Edge Cases
    
    @Test
    func testProcessingGazeOnLineWithoutVerseDoesNotCrash() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        // Verse on line 0, but we'll gaze at line 5
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        tracker.startTracking(pageNumber: 1, verses: [verse], pageFrame: pageFrame)
        
        // Gaze at line 5 (no verse there)
        let gazeY = yPositionForLine(5, pageWidth: 375, headerOffset: 40)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act & Assert - should not crash
        tracker.processGazePoint(gazePoint)
        #expect(tracker.activeLineIndex == 5)
        #expect(tracker.activeVerse == nil)
    }
    
    @Test
    func testEmptyVersesArrayDoesNotCrash() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        
        tracker.startTracking(pageNumber: 1, verses: [], pageFrame: pageFrame)
        
        // Act & Assert - should not crash
        let gazeY = yPositionForLine(5, pageWidth: 375, headerOffset: 40)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        tracker.processGazePoint(gazePoint)
        
        #expect(tracker.activeVerse == nil)
    }
    
    @Test
    func testStopTrackingWhenNotTrackingDoesNotCrash() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        
        // Act & Assert - should not crash
        tracker.stopTracking()
        #expect(tracker.isTracking == false)
    }
    
    @Test
    func testConfigurationCanBeChangedDuringTracking() async {
        // Arrange
        let tracker = ReadingProgressTracker()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let verses = [
            makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        ]
        
        tracker.startTracking(pageNumber: 1, verses: verses, pageFrame: pageFrame)
        
        // Act - change configuration during tracking
        tracker.dwellTimeThreshold = 0.5
        tracker.pageCompletionDwellTime = 2.0
        tracker.autoAdvanceEnabled = false
        
        // Assert - should not crash and values should be updated
        #expect(tracker.dwellTimeThreshold == 0.5)
        #expect(tracker.pageCompletionDwellTime == 2.0)
        #expect(tracker.autoAdvanceEnabled == false)
    }
}

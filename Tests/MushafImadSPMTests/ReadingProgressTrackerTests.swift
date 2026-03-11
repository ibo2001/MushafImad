import Foundation
import Testing
@testable import MushafImad

@Test @MainActor func trackerStartsWithNoVerse() {
    let tracker = ReadingProgressTracker()
    #expect(tracker.currentVerse == nil)
    #expect(tracker.isOnLastLine == false)
}

@Test @MainActor func trackerDetectsLastLine() {
    let tracker = ReadingProgressTracker()
    let point = GazePoint(x: 0.5, y: 0.95)
    tracker.update(gazePoint: point, page: 1)
    #expect(tracker.isOnLastLine == true)
}

@Test @MainActor func trackerNotOnLastLineForEarlyLines() {
    let tracker = ReadingProgressTracker()
    let point = GazePoint(x: 0.5, y: 0.3)
    tracker.update(gazePoint: point, page: 1)
    #expect(tracker.isOnLastLine == false)
}

@Test @MainActor func trackerResetClearsState() {
    let tracker = ReadingProgressTracker()
    let point = GazePoint(x: 0.5, y: 0.95)
    tracker.update(gazePoint: point, page: 1)
    tracker.reset()
    #expect(tracker.currentVerse == nil)
    #expect(tracker.isOnLastLine == false)
}

@Test func resolvedVerseEquality() {
    let a = GazeToVerseResolver.ResolvedVerse(
        chapterNumber: 1,
        verseNumber: 1,
        verseID: 1,
        confidence: 0.8
    )
    let b = GazeToVerseResolver.ResolvedVerse(
        chapterNumber: 1,
        verseNumber: 1,
        verseID: 1,
        confidence: 0.8
    )
    #expect(a == b)
}

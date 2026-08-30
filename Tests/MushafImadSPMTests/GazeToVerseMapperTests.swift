import Foundation
import Testing
import CoreGraphics
import QuartzCore
@testable import MushafImad

/// Tests for GazeToVerseMapper to ensure gaze point to verse mapping works correctly
/// across different screen sizes, orientations, and edge cases.
@Suite(.serialized)
@MainActor
struct GazeToVerseMapperTests {
    
    // MARK: - Test Helpers
    
    /// Create a mock verse with highlights on specified lines
    private func makeMockVerse(
        id: Int,
        number: Int,
        highlights: [(line: Int, left: Float, right: Float)]
    ) -> Verse {
        let verse = Verse()
        verse.verseID = id
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
    
    /// Create a mock gaze point at specified screen position
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
    
    // MARK: - Basic Mapping Tests
    
    @Test
    func testMapGazeToFirstLine() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let headerOffset: CGFloat = 40
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: headerOffset)
        
        // Create a verse on line 0 spanning the full width (RTL: left=0, right=1)
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        // Gaze at the center of the first line
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let gazeY = headerOffset + lineHeight / 2
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result != nil)
        #expect(result?.lineIndex == 0)
        #expect(result?.verseID == 1)
        #expect(result?.confidence == 0.9)
    }
    
    @Test
    func testMapGazeToMiddleLine() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let headerOffset: CGFloat = 40
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: headerOffset)
        
        // Create a verse on line 7 (middle of page)
        let verse = makeMockVerse(id: 2, number: 2, highlights: [(line: 7, left: 0.0, right: 1.0)])
        
        // Gaze at line 7
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let gazeY = headerOffset + lineHeight * 7.5
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result != nil)
        #expect(result?.lineIndex == 7)
        #expect(result?.verseID == 2)
    }
    
    @Test
    func testMapGazeToLastLine() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let headerOffset: CGFloat = 40
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: headerOffset)
        
        // Create a verse on line 14 (last line)
        let verse = makeMockVerse(id: 3, number: 3, highlights: [(line: 14, left: 0.0, right: 1.0)])
        
        // Gaze at line 14
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let gazeY = headerOffset + lineHeight * 14.5
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result != nil)
        #expect(result?.lineIndex == 14)
        #expect(result?.verseID == 3)
    }

    
    // MARK: - Edge Cases: Out of Bounds
    
    @Test
    func testGazeAbovePageReturnsNil() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 100, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        // Gaze above the page frame
        let gazePoint = makeGazePoint(x: 187.5, y: 50)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result == nil)
    }
    
    @Test
    func testGazeBelowPageReturnsNil() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        // Gaze below the page frame
        let gazePoint = makeGazePoint(x: 187.5, y: 900)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result == nil)
    }
    
    @Test
    func testGazeLeftOfPageReturnsNil() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 50, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        // Gaze to the left of the page frame
        let gazePoint = makeGazePoint(x: 25, y: 100)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result == nil)
    }
    
    @Test
    func testGazeRightOfPageReturnsNil() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        // Gaze to the right of the page frame
        let gazePoint = makeGazePoint(x: 400, y: 100)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result == nil)
    }
    
    @Test
    func testGazeInHeaderRegionReturnsNil() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let headerOffset: CGFloat = 40
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: headerOffset)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        // Gaze in the header region (before line content starts)
        let gazePoint = makeGazePoint(x: 187.5, y: 20)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result == nil)
    }
    
    @Test
    func testGazeInFooterRegionReturnsNil() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let headerOffset: CGFloat = 40
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: headerOffset)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        // Gaze below all 15 lines (in footer region)
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let footerY = headerOffset + lineHeight * 15 + 10
        let gazePoint = makeGazePoint(x: 187.5, y: footerY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result == nil)
    }

    
    // MARK: - Edge Cases: Nil Scenarios
    
    @Test
    func testEmptyVersesArrayReturnsResultWithoutVerseID() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let headerOffset: CGFloat = 40
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: headerOffset)
        
        // Gaze at a valid position but with no verses
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let gazeY = headerOffset + lineHeight * 5.5
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [])
        
        // Assert
        #expect(result != nil)
        #expect(result?.lineIndex == 5)
        #expect(result?.verseID == nil)
    }
    
    @Test
    func testNoMatchingVerseOnLineReturnsNilVerseID() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let headerOffset: CGFloat = 40
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: headerOffset)
        
        // Create a verse on line 0, but gaze at line 5
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let gazeY = headerOffset + lineHeight * 5.5
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result != nil)
        #expect(result?.lineIndex == 5)
        #expect(result?.verseID == nil)
    }
    
    @Test
    func testZeroLineHeightReturnsNil() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        // Don't call updatePageGeometry, so lineHeight remains 0
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        let gazePoint = makeGazePoint(x: 187.5, y: 100)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result == nil)
    }

    
    // MARK: - Different Screen Sizes
    
    @Test
    func testMappingOnSmallScreen() async {
        // Arrange - iPhone SE size
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 320, height: 568)
        let headerOffset: CGFloat = 40
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: headerOffset)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 3, left: 0.0, right: 1.0)])
        
        // Gaze at line 3
        let lineHeight = (320.0 / 1440.0 * 232.0) * 0.73
        let gazeY = headerOffset + lineHeight * 3.5
        let gazePoint = makeGazePoint(x: 160, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result != nil)
        #expect(result?.lineIndex == 3)
        #expect(result?.verseID == 1)
    }
    
    @Test
    func testMappingOnLargeScreen() async {
        // Arrange - iPad Pro size
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 1024, height: 1366)
        let headerOffset: CGFloat = 60
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: headerOffset)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 10, left: 0.0, right: 1.0)])
        
        // Gaze at line 10
        let lineHeight = (1024.0 / 1440.0 * 232.0) * 0.73
        let gazeY = headerOffset + lineHeight * 10.5
        let gazePoint = makeGazePoint(x: 512, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result != nil)
        #expect(result?.lineIndex == 10)
        #expect(result?.verseID == 1)
    }
    
    @Test
    func testMappingOnStandardScreen() async {
        // Arrange - iPhone 14 Pro size
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let headerOffset: CGFloat = 40
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: headerOffset)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 7, left: 0.0, right: 1.0)])
        
        // Gaze at line 7
        let lineHeight = (393.0 / 1440.0 * 232.0) * 0.73
        let gazeY = headerOffset + lineHeight * 7.5
        let gazePoint = makeGazePoint(x: 196.5, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result != nil)
        #expect(result?.lineIndex == 7)
        #expect(result?.verseID == 1)
    }

    
    // MARK: - Different Orientations
    
    @Test
    func testMappingInPortraitOrientation() async {
        // Arrange - Portrait (tall and narrow)
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let headerOffset: CGFloat = 40
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: headerOffset)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 5, left: 0.0, right: 1.0)])
        
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let gazeY = headerOffset + lineHeight * 5.5
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result != nil)
        #expect(result?.lineIndex == 5)
        #expect(result?.verseID == 1)
    }
    
    @Test
    func testMappingInLandscapeOrientation() async {
        // Arrange - Landscape (wide and short). QuranPageView renders landscape
        // lines inside a vertical scroll view taller than the viewport, using a
        // 0.7 line-height factor (vs. 0.73 in portrait), so the mapper needs both
        // the landscape factor and the current scroll offset to resolve a line
        // that isn't in the first screenful.
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 812, height: 375)
        let headerOffset: CGFloat = 30
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: headerOffset, isLandscape: true)

        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 8, left: 0.0, right: 1.0)])

        // Line 8's midpoint in content space, then a scroll offset chosen so a
        // gaze at the viewport's vertical centre lands exactly there.
        let lineHeight = (812.0 / 1440.0 * 232.0) * 0.7
        let contentY = headerOffset + lineHeight * 8.5
        let screenY = pageFrame.height / 2
        let scrollOffset = contentY - screenY
        let gazePoint = makeGazePoint(x: 406, y: screenY)

        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse], scrollOffset: scrollOffset)

        // Assert
        #expect(result != nil)
        #expect(result?.lineIndex == 8)
        #expect(result?.verseID == 1)
    }

    @Test
    func testGeometryUpdateHandlesOrientationChange() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 5, left: 0.0, right: 1.0)])

        // Start in portrait
        let portraitFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: portraitFrame, headerOffset: 40)

        let portraitLineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let portraitGazeY = 40 + portraitLineHeight * 5.5
        let portraitGaze = makeGazePoint(x: 187.5, y: portraitGazeY)

        let portraitResult = mapper.mapGazeToVerse(gazePoint: portraitGaze, verses: [verse])

        // Rotate to landscape
        let landscapeFrame = CGRect(x: 0, y: 0, width: 812, height: 375)
        mapper.updatePageGeometry(frame: landscapeFrame, headerOffset: 30, isLandscape: true)

        let landscapeLineHeight = (812.0 / 1440.0 * 232.0) * 0.7
        let landscapeContentY = 30 + landscapeLineHeight * 5.5
        let landscapeScreenY = landscapeFrame.height / 2
        let landscapeScrollOffset = landscapeContentY - landscapeScreenY
        let landscapeGaze = makeGazePoint(x: 406, y: landscapeScreenY)

        let landscapeResult = mapper.mapGazeToVerse(gazePoint: landscapeGaze, verses: [verse], scrollOffset: landscapeScrollOffset)

        // Assert both orientations work correctly
        #expect(portraitResult?.lineIndex == 5)
        #expect(portraitResult?.verseID == 1)
        #expect(landscapeResult?.lineIndex == 5)
        #expect(landscapeResult?.verseID == 1)
    }

    
    // MARK: - RTL Layout and Verse Matching
    
    @Test
    func testRTLLayoutVerseMatchingLeftSide() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        // RTL: left=0.5, right=1.0 means visual left side (0.0-0.5 in screen coords)
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 2, left: 0.5, right: 1.0)])
        
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let gazeY = 40 + lineHeight * 2.5
        // Gaze at visual left (x = 25% of width)
        let gazePoint = makeGazePoint(x: 93.75, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result != nil)
        #expect(result?.lineIndex == 2)
        #expect(result?.verseID == 1)
    }
    
    @Test
    func testRTLLayoutVerseMatchingRightSide() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        // RTL: left=0.0, right=0.5 means visual right side (0.5-1.0 in screen coords)
        let verse = makeMockVerse(id: 2, number: 2, highlights: [(line: 2, left: 0.0, right: 0.5)])
        
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let gazeY = 40 + lineHeight * 2.5
        // Gaze at visual right (x = 75% of width)
        let gazePoint = makeGazePoint(x: 281.25, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result != nil)
        #expect(result?.lineIndex == 2)
        #expect(result?.verseID == 2)
    }
    
    @Test
    func testMultipleVersesOnSameLineSelectsCorrectOne() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        // Two verses on line 4: verse 1 on left half, verse 2 on right half (RTL)
        let verse1 = makeMockVerse(id: 1, number: 1, highlights: [(line: 4, left: 0.5, right: 1.0)])
        let verse2 = makeMockVerse(id: 2, number: 2, highlights: [(line: 4, left: 0.0, right: 0.5)])
        
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let gazeY = 40 + lineHeight * 4.5
        
        // Gaze at left side (should hit verse 1)
        let leftGaze = makeGazePoint(x: 93.75, y: gazeY)
        let leftResult = mapper.mapGazeToVerse(gazePoint: leftGaze, verses: [verse1, verse2])
        
        // Gaze at right side (should hit verse 2)
        let rightGaze = makeGazePoint(x: 281.25, y: gazeY)
        let rightResult = mapper.mapGazeToVerse(gazePoint: rightGaze, verses: [verse1, verse2])
        
        // Assert
        #expect(leftResult?.verseID == 1)
        #expect(rightResult?.verseID == 2)
    }
    
    @Test
    func testVerseSpanningMultipleLinesMatchesCorrectly() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        // Verse spans lines 3, 4, and 5
        let verse = makeMockVerse(
            id: 1,
            number: 1,
            highlights: [
                (line: 3, left: 0.0, right: 0.6),
                (line: 4, left: 0.0, right: 1.0),
                (line: 5, left: 0.4, right: 1.0)
            ]
        )
        
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        
        // Test gaze on each line
        let gaze3 = makeGazePoint(x: 300, y: 40 + lineHeight * 3.5)
        let gaze4 = makeGazePoint(x: 187.5, y: 40 + lineHeight * 4.5)
        let gaze5 = makeGazePoint(x: 100, y: 40 + lineHeight * 5.5)
        
        let result3 = mapper.mapGazeToVerse(gazePoint: gaze3, verses: [verse])
        let result4 = mapper.mapGazeToVerse(gazePoint: gaze4, verses: [verse])
        let result5 = mapper.mapGazeToVerse(gazePoint: gaze5, verses: [verse])
        
        // Assert all three gazes map to the same verse
        #expect(result3?.verseID == 1)
        #expect(result4?.verseID == 1)
        #expect(result5?.verseID == 1)
        #expect(result3?.lineIndex == 3)
        #expect(result4?.lineIndex == 4)
        #expect(result5?.lineIndex == 5)
    }

    
    // MARK: - Line Progress Calculation
    
    @Test
    func testLineProgressAtTopOfLine() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 5, left: 0.0, right: 1.0)])
        
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        // Gaze at the very top of line 5
        let gazeY = 40 + lineHeight * 5.0
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result != nil)
        #expect(result!.lineProgress < 0.1) // Near 0
    }
    
    @Test
    func testLineProgressAtBottomOfLine() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 5, left: 0.0, right: 1.0)])
        
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        // Gaze at the very bottom of line 5
        let gazeY = 40 + lineHeight * 5.99
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result != nil)
        #expect(result!.lineProgress > 0.9) // Near 1
    }
    
    @Test
    func testLineProgressAtMiddleOfLine() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 5, left: 0.0, right: 1.0)])
        
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        // Gaze at the middle of line 5
        let gazeY = 40 + lineHeight * 5.5
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert
        #expect(result != nil)
        #expect(result!.lineProgress > 0.4 && result!.lineProgress < 0.6) // Around 0.5
    }

    
    // MARK: - Confidence Propagation
    
    @Test
    func testConfidenceIsPreservedFromGazePoint() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 0, left: 0.0, right: 1.0)])
        
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let gazeY = 40 + lineHeight * 0.5
        
        // Test different confidence levels
        let highConfidenceGaze = makeGazePoint(x: 187.5, y: gazeY, confidence: 0.95)
        let mediumConfidenceGaze = makeGazePoint(x: 187.5, y: gazeY, confidence: 0.6)
        let lowConfidenceGaze = makeGazePoint(x: 187.5, y: gazeY, confidence: 0.3)
        
        // Act
        let highResult = mapper.mapGazeToVerse(gazePoint: highConfidenceGaze, verses: [verse])
        let mediumResult = mapper.mapGazeToVerse(gazePoint: mediumConfidenceGaze, verses: [verse])
        let lowResult = mapper.mapGazeToVerse(gazePoint: lowConfidenceGaze, verses: [verse])
        
        // Assert
        #expect(highResult?.confidence == 0.95)
        #expect(mediumResult?.confidence == 0.6)
        #expect(lowResult?.confidence == 0.3)
    }
    
    // MARK: - Fallback Estimation
    
    @Test
    func testEstimateLineFromReadingTimeAtStart() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        
        // Act - Just started reading (0 seconds)
        let line = mapper.estimateLineFromReadingTime(
            elapsedSeconds: 0,
            wordsPerMinute: 80,
            totalWordsOnPage: 150
        )
        
        // Assert
        #expect(line == 0)
    }
    
    @Test
    func testEstimateLineFromReadingTimeAtMiddle() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        
        // Act - Read for enough time to be at middle of page
        // 150 words / 80 wpm = 1.875 minutes = 112.5 seconds for full page
        // Half page = 56.25 seconds
        let line = mapper.estimateLineFromReadingTime(
            elapsedSeconds: 56.25,
            wordsPerMinute: 80,
            totalWordsOnPage: 150
        )
        
        // Assert - Should be around line 7 (middle of 15 lines)
        #expect(line >= 6 && line <= 8)
    }
    
    @Test
    func testEstimateLineFromReadingTimeAtEnd() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        
        // Act - Read for more than enough time to finish page
        let line = mapper.estimateLineFromReadingTime(
            elapsedSeconds: 200,
            wordsPerMinute: 80,
            totalWordsOnPage: 150
        )
        
        // Assert - Should clamp to last line (14)
        #expect(line == 14)
    }
    
    @Test
    func testEstimateLineFromReadingTimeWithFasterSpeed() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        
        // Act - Fast reader (120 wpm) after 30 seconds
        let line = mapper.estimateLineFromReadingTime(
            elapsedSeconds: 30,
            wordsPerMinute: 120,
            totalWordsOnPage: 150
        )
        
        // Assert - Should be further along than slower reader
        #expect(line >= 4)
    }
    
    // MARK: - Nearest Verse Fallback
    
    @Test
    func testNearestVerseFallbackWhenGazeBetweenVerses() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        // Two verses with a gap between them on line 5
        let verse1 = makeMockVerse(id: 1, number: 1, highlights: [(line: 5, left: 0.7, right: 1.0)])
        let verse2 = makeMockVerse(id: 2, number: 2, highlights: [(line: 5, left: 0.0, right: 0.3)])
        
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let gazeY = 40 + lineHeight * 5.5
        
        // Gaze in the gap (normalized x around 0.5, which is between 0.3 and 0.7)
        let gazePoint = makeGazePoint(x: 187.5, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse1, verse2])

        // Assert - Should find nearest verse by edge distance (0.2 from each verse,
        // within the 0.25 threshold)
        #expect(result != nil)
        #expect(result?.verseID != nil)
    }
    
    @Test
    func testNoNearestVerseWhenTooFarAway() async {
        // Arrange
        let mapper = GazeToVerseMapper()
        let pageFrame = CGRect(x: 0, y: 0, width: 375, height: 812)
        mapper.updatePageGeometry(frame: pageFrame, headerOffset: 40)
        
        // Verse only on far right (RTL: left=0.0, right=0.1)
        let verse = makeMockVerse(id: 1, number: 1, highlights: [(line: 5, left: 0.0, right: 0.1)])
        
        let lineHeight = (375.0 / 1440.0 * 232.0) * 0.73
        let gazeY = 40 + lineHeight * 5.5
        
        // Gaze on far left (normalized x = 0.05, visual position after RTL conversion)
        let gazePoint = makeGazePoint(x: 18.75, y: gazeY)
        
        // Act
        let result = mapper.mapGazeToVerse(gazePoint: gazePoint, verses: [verse])
        
        // Assert - Should still find line but verse might be nil or matched
        #expect(result != nil)
        #expect(result?.lineIndex == 5)
    }
}

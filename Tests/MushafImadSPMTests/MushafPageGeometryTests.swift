import Foundation
import Testing
@testable import MushafImad

@Suite(.serialized)
@MainActor 
struct MushafPageGeometryTests {
    
 	// RTL mirroring
 	@Test func testMirroredX_ReverseCoordinates() {
		#expect(MushafPageGeometry.mirroredX(0.0) == 1.0)
		#expect(MushafPageGeometry.mirroredX(1.0) == 0.0)
		#expect(MushafPageGeometry.mirroredX(0.5) == 0.5)
		#expect(abs(MushafPageGeometry.mirroredX(0.9) - 0.1) < 0.001)
	}

    // Highlight inversion
	@Test func testHighlightPlacement_ScreenLeftComesFromStorageRight() {
        
		// Arrange
		let highlight = VerseHighlight()
		highlight.left = 0.2 
		highlight.right = 0.8
        let geometry = MushafPageGeometry(containerSize: CGSize(width: 375, height: 50))
		
		// Act
		let placement = geometry.highlightPlacement(for: highlight)

		// Assert
		#expect(placement.center.x == 187.5)
        #expect(abs(placement.size.width - 225.0) < 0.001)
        #expect(abs(placement.center.x - placement.size.width / 2 - 75.0) < 0.001)
        #expect(placement.center.x - placement.size.width / 2 != 300.0)
	}
    
    // Marker center across sizes
    @Test func testMarkerCenter_MatchesBaseline() {
        // Arrange
        let maker = VerseMarker()
        maker.centerX = 0.5
        maker.centerY = 0.5
        let geometries = [MushafPageGeometry(containerSize: CGSize(width: 375, height: 50)),
                          MushafPageGeometry(containerSize: CGSize(width: 375, height: 60))]
        
        // Act
        let smallPlacement = geometries[0].markerCenter(for: maker)
        let tallPlacement = geometries[1].markerCenter(for: maker)
        
        // Assert
        #expect(smallPlacement.x == 187.5)
        #expect(smallPlacement.y == 35.0)
        #expect(tallPlacement.y == 40.0)

    }
    
    // Chapter bar across sizes
    @Test func testChapterBarPlacement_MatchesBaseline() {
        // Arrange
        let header = ChapterHeader()
        header.centerX = 0.5
        header.centerY = 0.5
        let geometry = MushafPageGeometry(containerSize: CGSize(width: 375, height: 50))
        
        // Act
        let placement = geometry.chapterBarPlacement(for: header)
        
        // Assert
        #expect(placement.center.y == 33.0)

    }

}

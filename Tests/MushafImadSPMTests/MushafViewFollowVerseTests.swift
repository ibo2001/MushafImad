import Foundation
import Testing
@testable import MushafImad

/// Defect #1: the reader never followed the recitation. Playback drives a verse highlight, but
/// nothing moved the reader to the page that verse lives on, so the highlight silently walked off
/// the visible page.
@Suite
@MainActor
struct MushafViewFollowVerseTests {

    private func makeVerse(number: Int, page: Int?) -> Verse {
        let verse = Verse()
        verse.number = number
        if let page {
            let pageObject = Page()
            pageObject.number = page
            verse.page1441 = pageObject
        }
        return verse
    }

    @Test
    func followingVerseScrollsToThePageContainingIt() {
        let viewModel = MushafView.ViewModel()
        viewModel.scrollPosition = 1

        viewModel.followVerse(makeVerse(number: 255, page: 42))

        #expect(viewModel.scrollPosition == 42)
    }

    /// Playback clears its verse between chapters; that must not yank the reader to page 1.
    @Test
    func followingNoVerseLeavesTheReaderWhereItIs() {
        let viewModel = MushafView.ViewModel()
        viewModel.scrollPosition = 42

        viewModel.followVerse(nil)

        #expect(viewModel.scrollPosition == 42)
    }

    /// A verse whose page link is missing carries no destination, so it must not be treated as
    /// page 0 or reset the reader.
    @Test
    func followingVerseWithoutPageLeavesTheReaderWhereItIs() {
        let viewModel = MushafView.ViewModel()
        viewModel.scrollPosition = 42

        viewModel.followVerse(makeVerse(number: 1, page: nil))

        #expect(viewModel.scrollPosition == 42)
    }

    @Test
    func followingVerseAcrossPagesTracksEachPage() {
        let viewModel = MushafView.ViewModel()

        viewModel.followVerse(makeVerse(number: 1, page: 2))
        #expect(viewModel.scrollPosition == 2)

        viewModel.followVerse(makeVerse(number: 74, page: 3))
        #expect(viewModel.scrollPosition == 3)
    }
}

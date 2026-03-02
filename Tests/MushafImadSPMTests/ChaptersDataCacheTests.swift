import Foundation
import Testing
@testable import MushafImad

/// Tests for ChaptersDataCache to ensure caching logic works correctly and improves performance as expected.
@Suite(.serialized)
@MainActor
struct ChaptersDataCacheTests {
    
    func clearAfterEachTest() {
        ChaptersDataCache.shared.clearCache()
        ChaptersDataCache.shared.setRealmService(RealmService.shared) // Reset to default RealmService after tests
    }
    
    @Test
    func testInitialCacheIsEmpty() async {
        // Arrange
        let chaptersCache = ChaptersDataCache.shared
        let realmStub = RealmServiceStub()
        defer { clearAfterEachTest() }

        chaptersCache.setRealmService(realmStub)

        // Assert
        #expect(chaptersCache.allChapters.isEmpty)
        #expect(chaptersCache.allChaptersByPart.isEmpty)
        #expect(chaptersCache.allChaptersByHizb.isEmpty)
        #expect(chaptersCache.allChaptersByType.isEmpty)
        #expect(chaptersCache.isCached == false)
        #expect(chaptersCache.isPartsCached == false)
        #expect(chaptersCache.isHizbCached == false)
        #expect(chaptersCache.isTypeCached == false)
    }
    
    @Test
    func testLoadAndCachePopulatesChapters() async throws {
        // Arrange
        let chaptersCache = ChaptersDataCache.shared
        let realmStub = RealmServiceStub()
        defer { clearAfterEachTest() }
        var onBatchLoadedCalled = false
        let onBatchLoaded: (Int) -> Void = {_ in
            onBatchLoadedCalled = true
        }
        realmStub.chapters = [Chapter.mock]
        chaptersCache.setRealmService(realmStub)

        // Act
        try await chaptersCache.loadAndCache(onBatchLoaded: onBatchLoaded)
        
        // Assert
        #expect(chaptersCache.allChapters.count == 1)
        #expect(chaptersCache.isCached == true)
        #expect(onBatchLoadedCalled == true)
    }
    
    @Test func testLoadPartsGrouping() async throws {
        // Arrange
        let chaptersCache = ChaptersDataCache.shared
        let realmStub = RealmServiceStub()
        defer { clearAfterEachTest() }

        /// Prepare a chapter, verse & page using existing mocks
        let chapter = Chapter.mock
        let verse = Verse.mock
        let page = Page.mock
        let part = Part.makeMock(chapter: chapter, verse: verse, page: page)

        /// Configure stub
        realmStub.chapters = [chapter]
        realmStub.parts = [part]
        chaptersCache.setRealmService(realmStub)

        // Act
        try await chaptersCache.loadAndCache()
        try await chaptersCache.loadPartsGrouping()

        // Assert
        #expect(chaptersCache.isPartsCached == true)
        #expect(!chaptersCache.allChaptersByPart.isEmpty, "Expected ChaptersByPart not empty, did you forgot to call loadAndCache() first?")
        #expect(chaptersCache.allChaptersByPart.first?.chapters.isEmpty == false)
        #expect(chaptersCache.allChaptersByPart.first?.partNumber == part.number)
        #expect(chaptersCache.allChaptersByPart.first?.firstPage == page.number)
    }
    
    @Test func testLoadQuartersGrouping() async throws {
        // Arrange
        let chaptersCache = ChaptersDataCache.shared
        let realmStub = RealmServiceStub()
        defer { clearAfterEachTest() }

        /// Prepare chapter, verse and page using mocks
        let chapter = Chapter.mock
        let verse = Verse.mock
        let page = Page.mock
        let quarter = Quarter.makeMock(chapter: chapter, verse: verse, page: page)

        /// Configure stub
        realmStub.chapters = [chapter]
        realmStub.quarters = [quarter]
        chaptersCache.setRealmService(realmStub)

        // Act
      try await chaptersCache.loadAndCache()
        try await chaptersCache.loadQuartersGrouping()

        // Assert
        #expect(chaptersCache.isHizbCached == true)
        #expect(!chaptersCache.allChaptersByHizb.isEmpty, "Expected ChaptersByHizb not empty, did you forgot to call loadAndCache() first?")
        let foundHizb = chaptersCache.allChaptersByHizb.first { $0.hizbNumber == quarter.hizbNumber }
        #expect(foundHizb != nil)
        #expect(foundHizb?.quarters.first?.firstPage == page.number)
    }

    @Test func testLoadTypesGrouping() async throws {
        // Arrange
        let chaptersCache = ChaptersDataCache.shared
        let realmStub = RealmServiceStub()
        defer { clearAfterEachTest() }

        /// Create a meccan chapter
        let meccanChapter = Chapter.mock
        meccanChapter.isMeccan = true
        let meccanVerse = Verse.mock
        let meccanPage = Page.mock
        meccanVerse.page1441 = meccanPage
        meccanChapter.verses.append(meccanVerse)
        
        /// Create a medinan chapter
        let medinanChapter = Chapter.mockMedinan

        /// Configure stub
        realmStub.chapters = [meccanChapter, medinanChapter]
        chaptersCache.setRealmService(realmStub)

        // Act
        try await chaptersCache.loadAndCache()
        chaptersCache.loadTypesGrouping()

        // Assert
        #expect(chaptersCache.isTypeCached == true)
        #expect(chaptersCache.allChaptersByType.count == 2)
        let meccanGroup = chaptersCache.allChaptersByType.first { $0.id == "meccan" }
        let medinanGroup = chaptersCache.allChaptersByType.first { $0.id == "medinan" }
        #expect(meccanGroup != nil)
        #expect(medinanGroup != nil)
        #expect(meccanGroup?.firstPage == meccanPage.number)
        #expect(medinanGroup?.firstPage == medinanChapter.verses.first?.page1441?.number)
    }
    
    @Test func testClearCache() async throws {
        // Arrange
        let chaptersCache = ChaptersDataCache.shared
        let realmStub = RealmServiceStub()
        defer { clearAfterEachTest() }

        /// Prepare sample data using mocks
        let chapter = Chapter.mock
        let verse = Verse.mock
        let page = Page.mock
        let part = Part.makeMock(chapter: chapter, verse: verse, page: page)
        let quarter = Quarter.makeMock(chapter: chapter, verse: verse, page: page)

        realmStub.chapters = [chapter]
        realmStub.parts = [part]
        realmStub.quarters = [quarter]
        chaptersCache.setRealmService(realmStub)

        /// Load all caches first
        try await chaptersCache.loadAndCache()
        try await chaptersCache.loadPartsGrouping()
        try await chaptersCache.loadQuartersGrouping()
        chaptersCache.loadTypesGrouping()

        // Act
        chaptersCache.clearCache()

        // Assert
        #expect(chaptersCache.allChapters.isEmpty)
        #expect(chaptersCache.allChaptersByPart.isEmpty)
        #expect(chaptersCache.allChaptersByHizb.isEmpty)
        #expect(chaptersCache.allChaptersByType.isEmpty)
        #expect(chaptersCache.isCached == false)
        #expect(chaptersCache.isPartsCached == false)
        #expect(chaptersCache.isHizbCached == false)
        #expect(chaptersCache.isTypeCached == false)
    }

}

private class RealmServiceStub: RealmServiceProtocol {
    var chapters: [Chapter] = []
    var parts: [Part] = []
    var quarters: [Quarter] = []
    
    func fetchAllChaptersAsync() async throws -> [MushafImad.Chapter] { chapters }
    func fetchAllPartsAsync() async throws -> [MushafImad.Part] { parts }
    func fetchAllQuartersAsync() async throws -> [MushafImad.Quarter] { quarters }
}

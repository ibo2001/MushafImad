import Testing
@testable import MushafImad

// MARK: - MushafRealmConfiguration

@Suite("MushafRealmConfiguration")
struct MushafRealmConfigurationTests {
    @Test func bundledCaseExists() {
        let config = MushafRealmConfiguration.bundled
        _ = config // compiles = valid
    }

    @Test func inMemoryCaseExists() {
        let config = MushafRealmConfiguration.inMemory
        _ = config
    }

    @Test func customCaseCarriesURL() {
        let url = URL(fileURLWithPath: "/tmp/test.realm")
        if case .custom(let u) = MushafRealmConfiguration.custom(url: url) {
            #expect(u == url)
        } else {
            Issue.record("Expected .custom case")
        }
    }
}

// MARK: - RealmService (in-memory)

@Suite("RealmService")
@MainActor
struct RealmServiceTests {
    @Test func inMemoryInitializesSuccessfully() throws {
        let service = RealmService(configuration: .inMemory)
        try service.initialize()
        #expect(service.isInitialized)
    }

    @Test func inMemoryTotalPagesIsZero() throws {
        let service = RealmService(configuration: .inMemory)
        try service.initialize()
        #expect(service.getTotalPages() == 0)
    }

    @Test func inMemoryGetAllChaptersReturnsEmpty() throws {
        let service = RealmService(configuration: .inMemory)
        try service.initialize()
        let chapters = service.getAllChapters()
        #expect(chapters?.count == 0)
    }

    @Test func inMemoryGetPageReturnsNilForPage1() throws {
        let service = RealmService(configuration: .inMemory)
        try service.initialize()
        #expect(service.getPage(number: 1) == nil)
    }

    @Test func doubleInitializeIsIdempotent() throws {
        let service = RealmService(configuration: .inMemory)
        try service.initialize()
        try service.initialize() // should not throw
        #expect(service.isInitialized)
    }
}

// MARK: - ChaptersByType

@Suite("ChaptersByType")
struct ChaptersByTypeTests {
    @Test func meccanIDIsMeccan() {
        let group = ChaptersByType(id: "meccan", type: "Meccan", arabicType: "مكية",
                                   chapters: [], firstPage: nil, firstVerse: nil)
        #expect(group.isMeccan == true)
    }

    @Test func medinanIDIsNotMeccan() {
        let group = ChaptersByType(id: "medinan", type: "Medinan", arabicType: "مدنية",
                                   chapters: [], firstPage: nil, firstVerse: nil)
        #expect(group.isMeccan == false)
    }

    @Test func arbitraryIDIsNotMeccan() {
        let group = ChaptersByType(id: "other", type: "Other", arabicType: "أخرى",
                                   chapters: [], firstPage: nil, firstVerse: nil)
        #expect(group.isMeccan == false)
    }
}

// MARK: - ChaptersByHizb mock data

@Suite("ChaptersByHizb")
struct ChaptersByHizbTests {
    @Test func mockHizb1HasFourQuarters() {
        let hizb = ChaptersByHizb.mockHizb1
        #expect(hizb.quarters.count == 4)
    }

    @Test func mockHizb1HasCorrectNumber() {
        let hizb = ChaptersByHizb.mockHizb1
        #expect(hizb.hizbNumber == 1)
    }

    @Test func mockFirstQuarterBelongsToHizb1() {
        let quarter = ChaptersByQuarter.mockFirstQuarter
        #expect(quarter.hizbNumber == 1)
        #expect(quarter.hizbFraction == 1)
    }
}

// MARK: - ReciterService public init

@Suite("ReciterService")
@MainActor
struct ReciterServiceTests {
    @Test func customInitSortsByID() {
        let reciters = [
            ReciterService.ReciterInfo(id: 9, nameArabic: "تاسع", nameEnglish: "Ninth",
                                       rewaya: "Hafs", folderURL: "https://example.com/9/"),
            ReciterService.ReciterInfo(id: 1, nameArabic: "أول", nameEnglish: "First",
                                       rewaya: "Hafs", folderURL: "https://example.com/1/"),
        ]
        let service = ReciterService(reciters: reciters)
        #expect(service.availableReciters.map(\.id) == [1, 9])
    }

    @Test func customInitSelectsLowestIDFirst() {
        let reciters = [
            ReciterService.ReciterInfo(id: 5, nameArabic: "خامس", nameEnglish: "Fifth",
                                       rewaya: "Hafs", folderURL: "https://example.com/5/"),
            ReciterService.ReciterInfo(id: 2, nameArabic: "ثاني", nameEnglish: "Second",
                                       rewaya: "Hafs", folderURL: "https://example.com/2/"),
        ]
        let service = ReciterService(reciters: reciters)
        #expect(service.selectedReciter?.id == 2)
    }

    @Test func customInitEmptyListNoSelection() {
        let service = ReciterService(reciters: [])
        #expect(service.selectedReciter == nil)
        #expect(service.isLoading == false)
    }

    @Test func customInitIsNotLoading() {
        let service = ReciterService(reciters: [])
        #expect(service.isLoading == false)
    }

    @Test func getReciterByIDFindsExisting() {
        let reciters = [
            ReciterService.ReciterInfo(id: 7, nameArabic: "سابع", nameEnglish: "Seventh",
                                       rewaya: "Hafs", folderURL: "https://example.com/7/")
        ]
        let service = ReciterService(reciters: reciters)
        #expect(service.getReciterById(7) != nil)
        #expect(service.getReciterById(7)?.id == 7)
    }

    @Test func getReciterByIDReturnNilForMissing() {
        let service = ReciterService(reciters: [])
        #expect(service.getReciterById(99) == nil)
    }
}

// MARK: - ReciterInfo

@Suite("ReciterInfo")
struct ReciterInfoTests {
    @Test func audioBaseURLParsesValidURL() {
        let info = ReciterService.ReciterInfo(id: 1, nameArabic: "مشاري", nameEnglish: "Mishary",
                                              rewaya: "Hafs", folderURL: "https://cdn.example.com/audio/")
        #expect(info.audioBaseURL?.absoluteString == "https://cdn.example.com/audio/")
    }

    @Test func audioBaseURLReturnsNilForInvalidURL() {
        let info = ReciterService.ReciterInfo(id: 1, nameArabic: "مشاري", nameEnglish: "Mishary",
                                              rewaya: "Hafs", folderURL: "not a url ☠️")
        #expect(info.audioBaseURL == nil)
    }
}

// MARK: - MushafAssetConfiguration

@Suite("MushafAssetConfiguration")
@MainActor
struct MushafAssetConfigurationTests {
    @Test func resetRestoresDefaults() {
        MushafAssets.configuration.colorBundle = .main
        MushafAssets.reset()
        #expect(MushafAssets.configuration.colorBundle == nil)
    }

    @Test func additionalFontURLsDefaultsToEmpty() {
        let config = MushafAssetConfiguration()
        #expect(config.additionalFontURLs.isEmpty)
    }

    @Test func additionalFontURLsCanBeSet() {
        let url = URL(fileURLWithPath: "/tmp/MyFont.ttf")
        let config = MushafAssetConfiguration(additionalFontURLs: [url])
        #expect(config.additionalFontURLs.count == 1)
        #expect(config.additionalFontURLs.first == url)
    }
}

// MARK: - ChaptersDataCache

@Suite("ChaptersDataCache")
@MainActor
struct ChaptersDataCacheTests {
    @Test func clearCacheResetsIsCached() {
        let cache = ChaptersDataCache.shared
        cache.clearCache()
        #expect(cache.isCached == false)
    }

    @Test func clearCacheResetsChapters() {
        let cache = ChaptersDataCache.shared
        cache.clearCache()
        #expect(cache.allChapters.isEmpty)
    }

    @Test func clearCacheResetsGroupings() {
        let cache = ChaptersDataCache.shared
        cache.clearCache()
        #expect(cache.allChaptersByPart.isEmpty)
        #expect(cache.allChaptersByHizb.isEmpty)
        #expect(cache.allChaptersByType.isEmpty)
    }
}

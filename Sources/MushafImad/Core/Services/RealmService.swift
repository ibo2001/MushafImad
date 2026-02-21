//
//  RealmService.swift
//  Mushaf
//
//  Created by Ibrahim Qraiqe on 28/10/2025.
//

import Foundation
import RealmSwift

/// Describes how `RealmService` opens its Realm database.
public enum MushafRealmConfiguration {
    /// Uses the bundled `quran.realm` file, copying it to Application Support on first run.
    case bundled
    /// Opens a consumer-supplied Realm file directly. No file copying is performed.
    case custom(url: URL)
    /// Creates a transient in-memory Realm with the package schema. Useful for testing and previews.
    case inMemory
}

/// Facade around the bundled Realm database that powers Quran metadata.
@MainActor
public final class RealmService {
    /// The shared service instance that uses the bundled Quran database.
    public static let shared = RealmService()
    
    private var realm: Realm?
    private var realmConfig: Realm.Configuration?
    private let sourceConfiguration: MushafRealmConfiguration

    private init() {
        self.sourceConfiguration = .bundled
    }

    /// Creates a `RealmService` that opens its database using the given configuration.
    ///
    /// Call `try initialize()` before invoking any synchronous data-access methods
    /// (`getAllChapters()`, `getPage(number:)`, `getTotalPages()`, etc.).
    /// The async fetch methods (`fetchPageAsync`, `fetchAllChaptersAsync`, etc.)
    /// call `initialize()` automatically, but synchronous accessors return `nil`
    /// or fallback values if the database has not been opened yet.
    ///
    /// Example:
    /// ```swift
    /// let service = RealmService(configuration: .inMemory)
    /// try service.initialize()
    /// // Now safe to call synchronous accessors
    /// ```
    public init(configuration: MushafRealmConfiguration) {
        self.sourceConfiguration = configuration
    }
    
    // MARK: - Initialization
    
    /// Opens the Realm database for this service instance.
    ///
    /// Must be called before using any synchronous accessor. Async fetch methods call this automatically.
    public func initialize() throws {
        if realm != nil { return }

        switch sourceConfiguration {
        case .bundled:
            guard let bundledRealmURL = Bundle.mushafResources.url(forResource: "quran", withExtension: "realm") else {
                throw NSError(domain: "RealmService", code: 1,
                             userInfo: [NSLocalizedDescriptionKey: "Could not find quran.realm in bundle"])
            }
            let fileManager = FileManager.default
            guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw NSError(domain: "RealmService", code: 2,
                             userInfo: [NSLocalizedDescriptionKey: "Could not access Application Support directory"])
            }
            try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            let writableRealmURL = appSupportURL.appendingPathComponent("quran.realm")
            // The bundled realm is copied only on first run; subsequent schema updates
            // in the bundle won't propagate to existing installs.
            if !fileManager.fileExists(atPath: writableRealmURL.path) {
                try fileManager.copyItem(at: bundledRealmURL, to: writableRealmURL)
            }
            let config = RealmService.makeFileRealmConfiguration(fileURL: writableRealmURL)
            realmConfig = config
            realm = try Realm(configuration: config)

        case .custom(let url):
            let config = RealmService.makeFileRealmConfiguration(fileURL: url)
            realmConfig = config
            realm = try Realm(configuration: config)

        case .inMemory:
            let config = Realm.Configuration(
                inMemoryIdentifier: "mushaf-\(UUID().uuidString)",
                schemaVersion: RealmService.currentSchemaVersion
            )
            realmConfig = config
            realm = try Realm(configuration: config)
        }
    }
    
    /// Whether the underlying Realm database has been opened.
    public var isInitialized: Bool {
        return realm != nil
    }

    private static let currentSchemaVersion: UInt64 = 24

    private static func makeFileRealmConfiguration(fileURL: URL) -> Realm.Configuration {
        Realm.Configuration(
            fileURL: fileURL,
            schemaVersion: currentSchemaVersion,
            migrationBlock: { _, oldSchemaVersion in
                if oldSchemaVersion < currentSchemaVersion {}
            }
        )
    }
    
    // MARK: - Chapter (Surah) Operations
    
    /// Returns all chapters sorted by number, or `nil` if Realm is not initialized.
    public func getAllChapters() -> Results<Chapter>? {
        return realm?.objects(Chapter.self).sorted(byKeyPath: "number")
    }
    
    /// Fetch all chapters off the main actor and return frozen copies for thread safety
    public func fetchAllChaptersAsync() async throws -> [Chapter] {
        try initialize()
        guard let realmConfig else {
            throw NSError(domain: "RealmService", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Realm configuration unavailable"])
        }
        return try await withCheckedThrowingContinuation { continuation in
            let config = realmConfig
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: config)
                        let results = realm.objects(Chapter.self).sorted(byKeyPath: "number")
                        let frozen = Array(results.freeze())
                        continuation.resume(returning: frozen)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Returns the chapter with the given number, or `nil` if not found.
    public func getChapter(number: Int) -> Chapter? {
        return realm?.objects(Chapter.self).filter("number == %@", number).first?.freeze()
    }
    
    /// Returns the chapter that starts on or contains the given page.
    public func getChapterForPage(_ pageNumber: Int) -> Chapter? {
        // Get page and find first chapter that appears on it
        guard let page = getPage(number: pageNumber) else { return nil }
        
        // Check if page has chapter headers (new chapters starting on this page)
        if let firstHeader = page.chapterHeaders1441.first {
            return firstHeader.chapter?.freeze()
        }
        
        // Otherwise, get the chapter of the first verse on the page
        if let firstVerse = page.verses1441.first {
            return firstVerse.chapter?.freeze()
        }
        
        return nil
    }
    
    // MARK: - Page Operations
    
    /// Returns the page with the given number, or `nil` if not found.
    public func getPage(number: Int) -> Page? {
        return realm?.objects(Page.self).filter("number == %d", number).first?.freeze()
    }
    
    /// Fetch a page off the main actor and return a frozen copy for thread safety
    public func fetchPageAsync(number: Int) async -> Page? {
        do {
            try initialize()
        } catch {
            return nil
        }
        guard let realmConfig else { return nil }
        return await withCheckedContinuation { continuation in
            let config = realmConfig
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: config)
                        let page = realm.objects(Page.self)
                            .filter("number == %d", number)
                            .first?
                            .freeze()
                        continuation.resume(returning: page)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    /// Returns the total number of pages in the database, defaulting to 604.
    public func getTotalPages() -> Int {
        return realm?.objects(Page.self).count ?? 604
    }
    
    // MARK: - Page Header Operations
    
    /// Returns the header object for the given page and Mushaf type.
    public func getPageHeader(for pageNumber: Int, mushafType: MushafType = .hafs1441) -> PageHeader? {
        guard let page = getPage(number: pageNumber) else { return nil }
        
        switch mushafType {
        case .hafs1441:
            return page.header1441
        case .hafs1405:
            return page.header1405
        }
    }
    
    /// Returns a lightweight header value type for the given page and Mushaf type.
    public func getPageHeaderInfo(for pageNumber: Int, mushafType: MushafType = .hafs1441) -> PageHeaderInfo? {
        guard let header = getPageHeader(for: pageNumber, mushafType: mushafType) else { return nil }
        
        return PageHeaderInfo(
            partNumber: header.part?.number,
            partArabicTitle: header.part?.arabicTitle,
            partEnglishTitle: header.part?.englishTitle,
            hizbNumber: header.quarter?.hizbNumber,
            hizbFraction: header.quarter?.hizbFraction,
            quarterArabicTitle: header.quarter?.arabicTitle,
            quarterEnglishTitle: header.quarter?.englishTitle,
            chapters: header.chapters.map { chapter in
                ChapterInfo(
                    number: chapter.number,
                    arabicTitle: chapter.arabicTitle,
                    englishTitle: chapter.englishTitle
                )
            }
        )
    }
    
    // MARK: - Verse Operations
    
    /// Returns all verses on the given page for the specified Mushaf type.
    public func getVersesForPage(_ pageNumber: Int, mushafType: MushafType = .hafs1441) -> [Verse] {
        guard let page = getPage(number: pageNumber) else { return [] }
        
        switch mushafType {
        case .hafs1441:
            return Array(page.verses1441.freeze())
        case .hafs1405:
            return Array(page.verses1405.freeze())
        }
    }
    
    /// Returns all verses in the given chapter.
    public func getVersesForChapter(_ chapterNumber: Int) -> [Verse] {
        guard let chapter = getChapter(number: chapterNumber) else { return [] }
        return Array(chapter.verses.freeze())
    }
    
    /// Returns the verse identified by chapter and verse numbers, or `nil` if not found.
    public func getVerse(chapterNumber: Int, verseNumber: Int) -> Verse? {
        let humanReadableID = "\(chapterNumber)_\(verseNumber)"
        return realm?.objects(Verse.self).filter("humanReadableID == %@", humanReadableID).first?.freeze()
    }
    
    // MARK: - Part (Juz) Operations
    
    /// Returns the juz' with the given number, or `nil` if not found.
    public func getPart(number: Int) -> Part? {
        return realm?.objects(Part.self).filter("number == %@", number).first?.freeze()
    }
    
    /// Returns the juz' that contains the given page.
    public func getPartForPage(_ pageNumber: Int) -> Part? {
        guard let page = getPage(number: pageNumber) else { return nil }
        return page.header1441?.part?.freeze()
    }
    
    /// Returns the juz' that contains the given verse.
    public func getPartForVerse(chapterNumber: Int, verseNumber: Int) -> Part? {
        guard let verse = getVerse(chapterNumber: chapterNumber, verseNumber: verseNumber) else { return nil }
        return verse.part?.freeze()
    }
    
    /// Fetch all parts off the main actor and return frozen copies for thread safety
    public func fetchAllPartsAsync() async throws -> [Part] {
        try initialize()
        guard let realmConfig else {
            throw NSError(domain: "RealmService", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Realm configuration unavailable"])
        }
        return try await withCheckedThrowingContinuation { continuation in
            let config = realmConfig
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: config)
                        let results = realm.objects(Part.self).sorted(byKeyPath: "number")
                        let frozen = Array(results.freeze())
                        continuation.resume(returning: frozen)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // MARK: - Quarter (Hizb) Operations
    
    /// Returns the quarter (rub' hizb) for the given hizb number and fraction (0–3).
    public func getQuarter(hizbNumber: Int, fraction: Int) -> Quarter? {
        return realm?.objects(Quarter.self)
            .filter("hizbNumber == %@ AND hizbFraction == %@", hizbNumber, fraction).first?.freeze()
    }
    
    /// Returns the quarter that contains the given page.
    public func getQuarterForPage(_ pageNumber: Int) -> Quarter? {
        guard let page = getPage(number: pageNumber) else { return nil }
        return page.header1441?.quarter?.freeze()
    }
    
    /// Returns the quarter that contains the given verse.
    public func getQuarterForVerse(chapterNumber: Int, verseNumber: Int) -> Quarter? {
        guard let verse = getVerse(chapterNumber: chapterNumber, verseNumber: verseNumber) else { return nil }
        return verse.quarter?.freeze()
    }
    
    /// Fetch all quarters off the main actor and return frozen copies for thread safety
    public func fetchAllQuartersAsync() async throws -> [Quarter] {
        try initialize()
        guard let realmConfig else {
            throw NSError(domain: "RealmService", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Realm configuration unavailable"])
        }
        return try await withCheckedThrowingContinuation { continuation in
            let config = realmConfig
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: config)
                        // Fetch all quarters and sort in memory (by hizbNumber, then hizbFraction)
                        let results = realm.objects(Quarter.self)
                        let sorted = Array(results).sorted { q1, q2 in
                            if q1.hizbNumber != q2.hizbNumber {
                                return q1.hizbNumber < q2.hizbNumber
                            }
                            return q1.hizbFraction < q2.hizbFraction
                        }
                        let frozen = sorted.map { $0.freeze() }
                        continuation.resume(returning: frozen)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // MARK: - Section (Ruku) Operations
    
    /// Returns all ruku' sections for the given chapter.
    public func getSectionsForChapter(_ chapterNumber: Int) -> [QuranSection] {
        guard let chapter = getChapter(number: chapterNumber) else { return [] }
        
        // Find sections that contain verses from this chapter
        var sections: Set<QuranSection> = []
        for verse in chapter.verses {
            if let section = verse.section {
                sections.insert(section)
            }
        }
        
        return Array(sections).sorted { $0.identifier < $1.identifier }.map { $0.freeze() }
    }
    
    // MARK: - Search Operations
    
    /// Returns verses whose searchable text contains the query (case-insensitive).
    public func searchVerses(query: String) -> [Verse] {
        guard let realm = realm else { return [] }
        
        let predicate = NSPredicate(format: "searchableText CONTAINS[cd] %@", query)
        let results = realm.objects(Verse.self).filter(predicate)
        
        // Freeze results for thread safety
        return Array(results.freeze())
    }
    
    /// Returns chapters whose searchable text or keywords match the query (case-insensitive).
    public func searchChapters(query: String) -> [Chapter] {
        guard let realm = realm else { return [] }
        
        let predicate = NSPredicate(format: "searchableText CONTAINS[cd] %@ OR searchableKeywords CONTAINS[cd] %@", query, query)
        let results = realm.objects(Chapter.self).filter(predicate)
        
        // Freeze results for thread safety
        return Array(results.freeze())
    }
    
    // MARK: - Utility Methods
    
    /// Returns all chapters that appear on the given page.
    public func getChaptersOnPage(_ pageNumber: Int) -> [Chapter] {
        guard let page = getPage(number: pageNumber) else { return [] }
        
        var chapters: Set<Chapter> = []
        
        // Add chapters from headers (new chapters starting on this page)
        for header in page.chapterHeaders1441 {
            if let chapter = header.chapter {
                chapters.insert(chapter)
            }
        }
        
        // Add chapters from verses
        for verse in page.verses1441 {
            if let chapter = verse.chapter {
                chapters.insert(chapter)
            }
        }
        
        return Array(chapters).sorted { $0.number < $1.number }.map { $0.freeze() }
    }
    
    /// Returns the 15 verses of prostration (sajda) from the Quran.
    public func getSajdaVerses() -> [Verse] {
        // Find verses that contain sajda markers
        // This depends on how sajda information is stored in the Realm file
        // For now, we can search for specific verse IDs known to have sajda
        let sajdaVerseKeys = [
            "7:206", "13:15", "16:50", "17:109", "19:58",
            "22:18", "22:77", "25:60", "27:26", "32:15",
            "38:24", "41:38", "53:62", "84:21", "96:19"
        ]
        
        var sajdaVerses: [Verse] = []
        for key in sajdaVerseKeys {
            if let verse = realm?.objects(Verse.self)
                .filter("humanReadableID == %@", key).first?.freeze() {
                sajdaVerses.append(verse)
            }
        }
        
        return sajdaVerses
    }
}

// MARK: - Supporting Types

/// Supported Mushaf layouts that alter how verses map to pages.
public enum MushafType {
    case hafs1441  // Modern layout
    case hafs1405  // Traditional layout
}

// MARK: - Page Header Info Structure

/// Lightweight struct describing the contextual header for a Mushaf page.
public struct PageHeaderInfo {
    public let partNumber: Int?
    public let partArabicTitle: String?
    public let partEnglishTitle: String?
    public let hizbNumber: Int?
    public let hizbFraction: Int?
    public let quarterArabicTitle: String?
    public let quarterEnglishTitle: String?
    public let chapters: [ChapterInfo]

    /// Creates a page header info value from the given contextual metadata.
    public init(
        partNumber: Int?,
        partArabicTitle: String?,
        partEnglishTitle: String?,
        hizbNumber: Int?,
        hizbFraction: Int?,
        quarterArabicTitle: String?,
        quarterEnglishTitle: String?,
        chapters: [ChapterInfo]
    ) {
        self.partNumber = partNumber
        self.partArabicTitle = partArabicTitle
        self.partEnglishTitle = partEnglishTitle
        self.hizbNumber = hizbNumber
        self.hizbFraction = hizbFraction
        self.quarterArabicTitle = quarterArabicTitle
        self.quarterEnglishTitle = quarterEnglishTitle
        self.chapters = chapters
    }

    /// The hizb quarter progress marker derived from `hizbFraction`, or `nil` if at a full hizb boundary.
    public var hizbQuarterProgress: HizbQuarterProgress? {
        guard let fraction = hizbFraction else { return nil }
        switch fraction {
        case 1: return .quarter
        case 2: return .half
        case 3: return .threeQuarters
        default: return nil
        }
    }
    
    /// A localised Arabic string displaying the hizb number and fraction, or `nil` if unavailable.
    public var hizbDisplay: String? {
        guard let hizbNumber = hizbNumber else { return nil }
        
        if let fraction = hizbFraction, fraction > 0 {
            switch fraction {
            case 1: return "¼ الحزب \(hizbNumber)"
            case 2: return "½ الحزب \(hizbNumber)"
            case 3: return "¾ الحزب \(hizbNumber)"
            default: return "الحزب \(hizbNumber)"
            }
        }
        return "الحزب \(hizbNumber)"
    }
    
    /// A localised Arabic string displaying the juz' (part) number, or `nil` if unavailable.
    public var juzDisplay: String? {
        guard let partNumber = partNumber else { return nil }
        return "الجزء \(partNumber)"
    }
}

/// Summary of a chapter suitable for displaying in headers and lists.
public struct ChapterInfo {
    public let number: Int
    public let arabicTitle: String
    public let englishTitle: String

    /// Creates a chapter summary value.
    public init(number: Int, arabicTitle: String, englishTitle: String) {
        self.number = number
        self.arabicTitle = arabicTitle
        self.englishTitle = englishTitle
    }
}

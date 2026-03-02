//
//  RealmService.swift
//  Mushaf
//
//  Created by Ibrahim Qraiqe on 28/10/2025.
//

import Foundation
import RealmSwift

/// Protocol abstraction over RealmService to allow dependency injection and easier testing
@MainActor
public protocol RealmServiceProtocol: Sendable {
    func fetchAllChaptersAsync() async throws -> [Chapter]
    func fetchAllPartsAsync() async throws -> [Part]
    func fetchAllQuartersAsync() async throws -> [Quarter]
}

/// Facade around the bundled Realm database that powers Quran metadata.
@MainActor
public final class RealmService: RealmServiceProtocol {
    public static let shared = RealmService()
    
    private var realm: Realm?
    private var configuration: Realm.Configuration?
    
    private init() {}
    
    // MARK: - Initialization (Widget)
    
    /// Initializes Realm for the widget by copying the bundled database to a writable location first.
    /// This is necessary because the bundled database requires a schema upgrade (format 23 -> 24),
    /// which cannot be performed in read-only mode from the bundle.
    public func initializeForWidget() throws {
        if realm != nil {
            return
        }
        
        guard let bundledRealmURL = Bundle.mushafResources.url(forResource: "quran", withExtension: "realm") else {
            throw NSError(domain: "RealmService", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Could not find quran.realm in bundle"])
        }
        
        let fileManager = FileManager.default
        // Widgets usually can't write to Application Support safely without App Groups,
        // but we can write to the extension's local Cache or Documents directory.
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "RealmService", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Could not access Caches directory for Widget"])
        }
        
        let writableRealmURL = cachesURL.appendingPathComponent("quran_widget.realm")
        
        // Copy if it doesn't exist
        if !fileManager.fileExists(atPath: writableRealmURL.path) {
            try fileManager.copyItem(at: bundledRealmURL, to: writableRealmURL)
        }
        
        // Configure Realm with automatic migration (aligned with main app)
        let config = Realm.Configuration(
            fileURL: writableRealmURL,
            schemaVersion: 24,
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < 24 {
                    // Perform any necessary migration
                }
            }
        )
        
        configuration = config
        realm = try Realm(configuration: config)
    }
    
    // MARK: - Initialization
    
    public func initialize() throws {
        // Skip initialization if already initialized
        if realm != nil {
            return
        }
        
        // Get the path to the bundled Realm file
        guard let bundledRealmURL = Bundle.mushafResources.url(forResource: "quran", withExtension: "realm") else {
            throw NSError(domain: "RealmService", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Could not find quran.realm in bundle"])
        }
        
        // Get the Application Support directory (writable location)
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "RealmService", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Could not access Application Support directory"])
        }
        
        // Create Application Support directory if it doesn't exist
        try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        
        // Destination path for the writable Realm file
        let writableRealmURL = appSupportURL.appendingPathComponent("quran.realm")
        
        // Copy the bundled Realm file to writable location if it doesn't exist (ONE TIME)
        if !fileManager.fileExists(atPath: writableRealmURL.path) {
            try fileManager.copyItem(at: bundledRealmURL, to: writableRealmURL)
        }
        
        // Configure Realm with automatic migration (optimized)
        var config = Realm.Configuration(
            fileURL: writableRealmURL,
            schemaVersion: 24,
            migrationBlock: { migration, oldSchemaVersion in
                // Lightweight migration - no logging to avoid performance hit
                if oldSchemaVersion < 24 {
                    // Perform any necessary migration
                }
            }
        )
        
        // Disable file locking for better performance (read-only after migration)
        config.readOnly = false
        configuration = config
        
        // Initialize Realm
        realm = try Realm(configuration: config)
        
        //let chapterCount = realm?.objects(Chapter.self).count ?? 0
    }
    
    /// Check if Realm is initialized
    public var isInitialized: Bool {
        return realm != nil
    }
    
    // MARK: - Chapter (Surah) Operations
    
    public func getAllChapters() -> Results<Chapter>? {
        return realm?.objects(Chapter.self).sorted(byKeyPath: "number")
    }
    
    /// Fetch all chapters off the main actor and return frozen copies for thread safety
    public func fetchAllChaptersAsync() async throws -> [Chapter] {
        try initialize()
        guard let configuration else {
            throw NSError(domain: "RealmService", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Realm configuration unavailable"])
        }
        return try await withCheckedThrowingContinuation { continuation in
            let config = configuration
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
    
    public func getChapter(number: Int) -> Chapter? {
        return realm?.objects(Chapter.self).filter("number == %@", number).first?.freeze()
    }
    
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
        guard let configuration else { return nil }
        return await withCheckedContinuation { continuation in
            let config = configuration
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
    
    public func getTotalPages() -> Int {
        return realm?.objects(Page.self).count ?? 604
    }
    
    // MARK: - Page Header Operations
    
    public func getPageHeader(for pageNumber: Int, mushafType: MushafType = .hafs1441) -> PageHeader? {
        guard let page = getPage(number: pageNumber) else { return nil }
        
        switch mushafType {
        case .hafs1441:
            return page.header1441
        case .hafs1405:
            return page.header1405
        }
    }
    
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
    
    public func getVersesForPage(_ pageNumber: Int, mushafType: MushafType = .hafs1441) -> [Verse] {
        guard let page = getPage(number: pageNumber) else { return [] }
        
        switch mushafType {
        case .hafs1441:
            return Array(page.verses1441.freeze())
        case .hafs1405:
            return Array(page.verses1405.freeze())
        }
    }
    
    public func getVersesForChapter(_ chapterNumber: Int) -> [Verse] {
        guard let chapter = getChapter(number: chapterNumber) else { return [] }
        return Array(chapter.verses.freeze())
    }
    
    public func getVerse(chapterNumber: Int, verseNumber: Int) -> Verse? {
        let humanReadableID = "\(chapterNumber)_\(verseNumber)"
        return realm?.objects(Verse.self).filter("humanReadableID == %@", humanReadableID).first?.freeze()
    }
    
    public func getRandomAyah(for date: Date) -> Verse? {
        guard let realm = realm else { return nil }
        
        let allVerses = realm.objects(Verse.self)
        let count = allVerses.count
        guard count > 0 else { return nil }
        
        let daysSinceEpoch = Int(date.timeIntervalSince1970 / 86400)
        let index = abs(daysSinceEpoch) % count
        
        // Results are unordered. Using an offset fetch:
        return allVerses[index].freeze()
    }
    
    // MARK: - Part (Juz) Operations
    
    public func getPart(number: Int) -> Part? {
        return realm?.objects(Part.self).filter("number == %@", number).first?.freeze()
    }
    
    public func getPartForPage(_ pageNumber: Int) -> Part? {
        guard let page = getPage(number: pageNumber) else { return nil }
        return page.header1441?.part?.freeze()
    }
    
    public func getPartForVerse(chapterNumber: Int, verseNumber: Int) -> Part? {
        guard let verse = getVerse(chapterNumber: chapterNumber, verseNumber: verseNumber) else { return nil }
        return verse.part?.freeze()
    }
    
    /// Fetch all parts off the main actor and return frozen copies for thread safety
    public func fetchAllPartsAsync() async throws -> [Part] {
        try initialize()
        guard let configuration else {
            throw NSError(domain: "RealmService", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Realm configuration unavailable"])
        }
        return try await withCheckedThrowingContinuation { continuation in
            let config = configuration
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
    
    public func getQuarter(hizbNumber: Int, fraction: Int) -> Quarter? {
        return realm?.objects(Quarter.self)
            .filter("hizbNumber == %@ AND hizbFraction == %@", hizbNumber, fraction).first?.freeze()
    }
    
    public func getQuarterForPage(_ pageNumber: Int) -> Quarter? {
        guard let page = getPage(number: pageNumber) else { return nil }
        return page.header1441?.quarter?.freeze()
    }
    
    public func getQuarterForVerse(chapterNumber: Int, verseNumber: Int) -> Quarter? {
        guard let verse = getVerse(chapterNumber: chapterNumber, verseNumber: verseNumber) else { return nil }
        return verse.quarter?.freeze()
    }
    
    /// Fetch all quarters off the main actor and return frozen copies for thread safety
    public func fetchAllQuartersAsync() async throws -> [Quarter] {
        try initialize()
        guard let configuration else {
            throw NSError(domain: "RealmService", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Realm configuration unavailable"])
        }
        return try await withCheckedThrowingContinuation { continuation in
            let config = configuration
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
    
    public func searchVerses(query: String) -> [Verse] {
        guard let realm = realm else { return [] }
        
        let predicate = NSPredicate(format: "searchableText CONTAINS[cd] %@", query)
        let results = realm.objects(Verse.self).filter(predicate)
        
        // Freeze results for thread safety
        return Array(results.freeze())
    }
    
    public func searchChapters(query: String) -> [Chapter] {
        guard let realm = realm else { return [] }
        
        let predicate = NSPredicate(format: "searchableText CONTAINS[cd] %@ OR searchableKeywords CONTAINS[cd] %@", query, query)
        let results = realm.objects(Chapter.self).filter(predicate)
        
        // Freeze results for thread safety
        return Array(results.freeze())
    }
    
    // MARK: - Utility Methods
    
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
    
    public var hizbQuarterProgress: HizbQuarterProgress? {
        guard let fraction = hizbFraction else { return nil }
        switch fraction {
        case 1: return .quarter
        case 2: return .half
        case 3: return .threeQuarters
        default: return nil
        }
    }
    
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
}

//
//  ChaptersDataCache.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 05/11/2025.
//

import Foundation
import RealmSwift

/// Singleton cache for chapters data to avoid reloading on every view appearance
@MainActor
public final class ChaptersDataCache {
    public static let shared = ChaptersDataCache()
    
    // Cached data
    public private(set) var allChapters: [Chapter] = []
    public private(set) var allChaptersByPart: [ChaptersByPart] = []
    public private(set) var allChaptersByHizb: [ChaptersByHizb] = []
    public private(set) var allChaptersByType: [ChaptersByType] = []
    
    public private(set) var isCached = false
    public private(set) var isPartsCached = false
    public private(set) var isHizbCached = false
    public private(set) var isTypeCached = false
    
    private init() {}

    // Tracks which RealmService last populated this cache so we can
    // invalidate when a different service instance is used.
    private var populatingServiceID: ObjectIdentifier?
    
    /// Fetches all chapters from the given service, caches them, and notifies
    /// the caller via `onBatchLoaded` when the full chapter list is ready.
    ///
    /// If the cache is already populated by the same `service` instance this
    /// method returns immediately without making any database calls. Passing a
    /// different `service` instance invalidates the cache automatically before
    /// reloading.
    ///
    /// - Parameters:
    ///   - service: The `RealmService` used to fetch chapter data. Defaults to
    ///     `RealmService.shared`.
    ///   - onBatchLoaded: Optional closure called once with the total number of
    ///     cached chapters after the fetch completes.
    /// - Throws: Any error thrown by the underlying `RealmService` fetch.
    public func loadAndCache(using service: RealmService = .shared, onBatchLoaded: ((Int) -> Void)? = nil) async throws {
        let incomingID = ObjectIdentifier(service)
        if isCached && !allChapters.isEmpty && populatingServiceID == incomingID {
            return
        }
        // Different service instance — invalidate stale cache before reloading.
        if populatingServiceID != incomingID {
            clearCache()
        }

        let chapters = try await service.fetchAllChaptersAsync()
        allChapters = chapters
                
        // Notify that chapters are ready
        onBatchLoaded?(allChapters.count)
        
        isCached = true
        populatingServiceID = incomingID
    }
    
    /// Lazily loads and caches the chapters-by-juz' grouping from the database.
    ///
    /// This method is a no-op if the parts grouping is already cached for the
    /// same `service` instance. Call ``loadAndCache(using:onBatchLoaded:)`` first
    /// so that the chapter list is available for the grouping step.
    ///
    /// - Parameter service: The `RealmService` used to fetch part data. Defaults
    ///   to `RealmService.shared`.
    /// - Throws: Any error thrown by the underlying `RealmService` fetch.
    public func loadPartsGrouping(using service: RealmService = .shared) async throws {
        guard !isPartsCached || populatingServiceID != ObjectIdentifier(service) else { return }
        let parts = try await service.fetchAllPartsAsync()
        
        // Create a lookup dictionary for chapters by number for efficient access
        let chaptersDict = Dictionary(uniqueKeysWithValues: allChapters.map { ($0.number, $0) })
        
        allChaptersByPart = parts.compactMap { part -> ChaptersByPart? in
            // Use the part.chapters relationship directly
            let partChapters = Array(part.chapters)
                .compactMap { chaptersDict[$0.number] }
                .sorted { $0.number < $1.number }
            
            guard !partChapters.isEmpty else { return nil }
            
            // Get first verse from the Part's verses
            let firstVerse = Array(part.verses).min(by: { $0.verseID < $1.verseID })
            
            return ChaptersByPart(
                id: part.identifier,
                partNumber: part.number,
                arabicTitle: part.arabicTitle,
                englishTitle: part.englishTitle,
                chapters: partChapters,
                firstPage: firstVerse?.page1441?.number,
                firstVerse: firstVerse
            )
        }
        
        isPartsCached = true
    }
    
    /// Lazily loads and caches the chapters-by-hizb/quarter grouping from the database.
    ///
    /// This method is a no-op if the quarters grouping is already cached for the
    /// same `service` instance. Call ``loadAndCache(using:onBatchLoaded:)`` first
    /// so that the chapter list is available for the grouping step.
    ///
    /// - Parameter service: The `RealmService` used to fetch quarter data. Defaults
    ///   to `RealmService.shared`.
    /// - Throws: Any error thrown by the underlying `RealmService` fetch.
    public func loadQuartersGrouping(using service: RealmService = .shared) async throws {
        guard !isHizbCached || populatingServiceID != ObjectIdentifier(service) else { return }
        let quarters = try await service.fetchAllQuartersAsync()
        
        // Create a lookup dictionary for chapters by number for efficient access
        let chaptersDict = Dictionary(uniqueKeysWithValues: allChapters.map { ($0.number, $0) })
        
        // Group quarters by hizbNumber
        var hizbDict: [Int: [Quarter]] = [:]
        for quarter in quarters {
            if hizbDict[quarter.hizbNumber] == nil {
                hizbDict[quarter.hizbNumber] = []
            }
            hizbDict[quarter.hizbNumber]?.append(quarter)
        }
        
        // Build ChaptersByHizb structure
        allChaptersByHizb = hizbDict.keys.sorted().compactMap { hizbNumber -> ChaptersByHizb? in
            guard let quartersInHizb = hizbDict[hizbNumber] else { return nil }
            
            // Create quarters for all 4 fractions (0, 1, 2, 3)
            let quarters: [ChaptersByQuarter] = (0...3).compactMap { fraction -> ChaptersByQuarter? in
                guard let quarter = quartersInHizb.first(where: { $0.hizbFraction == fraction }) else {
                    return nil
                }
                
                // Get chapters that belong to this quarter
                // We need to find chapters that have verses in this quarter
                var quarterChapters: Set<Int> = []
                for verse in quarter.verses {
                    if let chapterNumber = verse.chapter?.number {
                        quarterChapters.insert(chapterNumber)
                    }
                }
                
                let quarterChaptersArray = quarterChapters.compactMap { chaptersDict[$0] }
                    .sorted { $0.number < $1.number }
                
                guard !quarterChaptersArray.isEmpty else { return nil }
                
                // Get first verse from the quarter's verses
                let firstVerse = Array(quarter.verses).min(by: { $0.verseID < $1.verseID })
                
                return ChaptersByQuarter(
                    id: quarter.identifier,
                    quarterNumber: quarter.identifier,
                    hizbNumber: hizbNumber,
                    hizbFraction: fraction,
                    arabicTitle: quarter.arabicTitle,
                    englishTitle: quarter.englishTitle,
                    chapters: quarterChaptersArray,
                    firstPage: firstVerse?.page1441?.number,
                    firstVerse: firstVerse
                )
            }
            
            guard !quarters.isEmpty else { return nil }
            
            return ChaptersByHizb(
                id: hizbNumber,
                hizbNumber: hizbNumber,
                quarters: quarters
            )
        }
        
        isHizbCached = true
    }
    
    /// Builds the Meccan/Medinan chapter grouping from the already-cached chapter list.
    ///
    /// This method is synchronous and requires ``loadAndCache(using:onBatchLoaded:)``
    /// to have completed successfully beforehand. It is a no-op when the type
    /// grouping is already cached.
    public func loadTypesGrouping() {
        guard isCached, !allChapters.isEmpty else {
            return
        }
        
        guard !isTypeCached else {
            return
        }
        
        // Simple sort by type - no need to iterate through verses
        let meccanChapters = allChapters.filter { $0.isMeccan }.sorted { $0.number < $1.number }
        let medinanChapters = allChapters.filter { !$0.isMeccan }.sorted { $0.number < $1.number }
        
        // Get first verse from each type (from first chapter)
        let meccanFirstVerse = meccanChapters.first?.verses.first
        let medinanFirstVerse = medinanChapters.first?.verses.first
        
        allChaptersByType = [
            ChaptersByType(
                id: "meccan",
                type: "Meccan",
                arabicType: "مكية",
                chapters: meccanChapters,
                firstPage: meccanFirstVerse?.page1441?.number,
                firstVerse: meccanFirstVerse
            ),
            ChaptersByType(
                id: "medinan",
                type: "Medinan",
                arabicType: "مدنية",
                chapters: medinanChapters,
                firstPage: medinanFirstVerse?.page1441?.number,
                firstVerse: medinanFirstVerse
            )
        ]
        
        isTypeCached = true
    }
    
    /// Resets all cached data and invalidates the service-identity record.
    ///
    /// After calling this method all `isCached` flags are `false` and every
    /// cached collection is empty. The next call to any load method will
    /// re-fetch data from the database.
    public func clearCache() {
        allChapters = []
        allChaptersByPart = []
        allChaptersByHizb = []
        allChaptersByType = []
        isCached = false
        isPartsCached = false
        isHizbCached = false
        isTypeCached = false
        populatingServiceID = nil
    }
}


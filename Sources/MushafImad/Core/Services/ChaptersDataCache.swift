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
    public static let shared = ChaptersDataCache(realmService: RealmService.shared)
    
    // Injected Realm service (defaults to the singleton). Mutable so tests can override.
    private var realmService: RealmServiceProtocol
    
    // Cached data
    public private(set) var allChapters: [Chapter] = []
    public private(set) var allChaptersByPart: [ChaptersByPart] = []
    public private(set) var allChaptersByHizb: [ChaptersByHizb] = []
    public private(set) var allChaptersByType: [ChaptersByType] = []
    
    public private(set) var isCached = false
    public private(set) var isPartsCached = false
    public private(set) var isHizbCached = false
    public private(set) var isTypeCached = false
    
    // Default private initializer uses the shared RealmService
    private init(realmService: RealmServiceProtocol) {
        self.realmService = realmService
    }

    /// Allow tests (using @testable) to override the RealmService on the shared instance
    package func setRealmService(_ service: RealmServiceProtocol) {
        self.realmService = service
    }
    
    /// Load and cache chapters data only (with progressive loading callback)
    /// Grouped data is loaded on-demand via separate methods
    public func loadAndCache(onBatchLoaded: ((Int) -> Void)? = nil) async throws {
        // Skip if already cached
        if isCached && !allChapters.isEmpty {
            return
        }
        
        // Load chapters off the main actor to avoid blocking UI
        let chapters = try await realmService.fetchAllChaptersAsync()
        allChapters = chapters
                
        // Notify that chapters are ready
        onBatchLoaded?(allChapters.count)
        
        isCached = true
    }
    
    /// Load and cache parts grouping (lazy-loaded) - directly from Parts in database
    public func loadPartsGrouping() async throws {
        guard !isPartsCached else {
            return
        }
        
        let parts = try await realmService.fetchAllPartsAsync()
        
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
    
    /// Load and cache quarters grouping (lazy-loaded) - directly from Quarters in database
    public func loadQuartersGrouping() async throws {
        guard !isHizbCached else {
            return
        }
        
        let quarters = try await realmService.fetchAllQuartersAsync()
        
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
    
    /// Load and cache types grouping (lazy-loaded) - simple sort by isMeccan
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
    
    /// Clear cache (useful for testing or force refresh)
    public func clearCache() {
        allChapters = []
        allChaptersByPart = []
        allChaptersByHizb = []
        allChaptersByType = []
        isCached = false
        isPartsCached = false
        isHizbCached = false
        isTypeCached = false
    }
}

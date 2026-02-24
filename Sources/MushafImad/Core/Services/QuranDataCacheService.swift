//
//  QuranDataCacheService.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 31/10/2025.
//

import Foundation
import RealmSwift

/// Service to cache Quran data from Realm for quick access
@MainActor
public final class QuranDataCacheService {
    public static let shared = QuranDataCacheService()
    
    // Cached data structures
    private var cachedVerses: [Int: [Verse]] = [:] // Page number -> Verses
    private var cachedPageHeaders: [Int: PageHeaderInfo] = [:] // Page number -> Header info
    private var cachedChapterVerses: [Int: [Verse]] = [:] // Chapter number -> Verses
    
    private let realmService = RealmService.shared
    
    public init() {}
    
    // MARK: - Cache Management
    
    /// Pre-fetch and cache data for a specific page
    public func cachePageData(_ pageNumber: Int) async {
        // Cache verses for this page
        let verses = realmService.getVersesForPage(pageNumber)
        if !verses.isEmpty {
            cachedVerses[pageNumber] = verses
        }
        
        // Cache page header
        if let headerInfo = realmService.getPageHeaderInfo(for: pageNumber) {
            cachedPageHeaders[pageNumber] = headerInfo
        }
        
        // Cache chapter verses for chapters on this page
        let chapters = realmService.getChaptersOnPage(pageNumber)
        for chapter in chapters {
            if cachedChapterVerses[chapter.number] == nil {
                let chapterVerses = realmService.getVersesForChapter(chapter.number)
                if !chapterVerses.isEmpty {
                    cachedChapterVerses[chapter.number] = chapterVerses
                }
            }
        }
    }
    
    /// Pre-fetch and cache data for a range of pages (e.g., for a chapter)
    public func cachePageRange(_ pageRange: ClosedRange<Int>) async {
        for pageNumber in pageRange {
            await cachePageData(pageNumber)
        }
    }
    
    /// Pre-fetch and cache data for a specific chapter
    public func cacheChapterData(_ chapter: Chapter) async {
        // Cache chapter verses
        let verses = realmService.getVersesForChapter(chapter.number)
        if !verses.isEmpty {
            cachedChapterVerses[chapter.number] = verses
        }
        
        // Cache all pages in this chapter
        await cachePageRange(chapter.startPage...chapter.endPage)
    }
    
    // MARK: - Cache Retrieval
    
    /// Get cached verses for a page (returns nil if not cached)
    public func getCachedVerses(forPage pageNumber: Int) -> [Verse]? {
        return cachedVerses[pageNumber]
    }
    
    /// Get cached page header (returns nil if not cached)
    public func getCachedPageHeader(forPage pageNumber: Int) -> PageHeaderInfo? {
        return cachedPageHeaders[pageNumber]
    }
    
    /// Get cached verses for a chapter (returns nil if not cached)
    public func getCachedChapterVerses(forChapter chapterNumber: Int) -> [Verse]? {
        return cachedChapterVerses[chapterNumber]
    }
    
    /// Check if page data is cached
    public func isPageCached(_ pageNumber: Int) -> Bool {
        return cachedVerses[pageNumber] != nil && cachedPageHeaders[pageNumber] != nil
    }
    
    /// Check if chapter data is fully cached
    public func isChapterCached(_ chapter: Chapter) -> Bool {
        guard cachedChapterVerses[chapter.number] != nil else { return false }
        
        // Check if all pages are cached
        for pageNumber in chapter.startPage...chapter.endPage {
            if !isPageCached(pageNumber) {
                return false
            }
        }
        return true
    }
    
    // MARK: - Cache Management
    
    /// Clear cached data for a specific page
    public func clearPageCache(_ pageNumber: Int) {
        cachedVerses.removeValue(forKey: pageNumber)
        cachedPageHeaders.removeValue(forKey: pageNumber)
    }
    
    /// Clear cached data for a chapter
    public func clearChapterCache(_ chapterNumber: Int) {
        cachedChapterVerses.removeValue(forKey: chapterNumber)
    }
    
    /// Clear all cached data
    public func clearAllCache() {
        cachedVerses.removeAll()
        cachedPageHeaders.removeAll()
        cachedChapterVerses.removeAll()
    }
    
    /// Get cache statistics
    public func getCacheStats() -> CacheStats {
        return CacheStats(
            cachedPagesCount: cachedVerses.count,
            cachedChaptersCount: cachedChapterVerses.count,
            totalVersesCached: cachedVerses.values.reduce(0) { $0 + $1.count }
        )
    }
}

// MARK: - Supporting Types

public struct CacheStats {
    public let cachedPagesCount: Int
    public let cachedChaptersCount: Int
    public let totalVersesCached: Int
}


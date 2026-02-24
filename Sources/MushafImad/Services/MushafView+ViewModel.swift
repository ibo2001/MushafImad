//
//  MushafView+ViewModel.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 31/10/2025.
//

import SwiftUI
import RealmSwift

extension MushafView {
    @Observable
    @MainActor
    /// Screen-facing orchestration for the Mushaf reader, responsible for
    /// coordinating cached Realm data with SwiftUI state.
    public final class ViewModel {
        // UI State
        public var presentedVerse: Verse?
        public var selectedVerse: Verse?  // Track currently selected verse
        public var tafsirVerse: Verse?  // Store verse for Tafsir sheet
        public var isInitialPageReady = false
        public var scrollPosition: Int?
        
        // Data State
        public var currentPage: Int = 1 {
            didSet {
                if currentPage != oldValue {
                    schedulePageLoad(for: currentPage)
                }
            }
        }
        public var chapters: [Chapter] = []
        public var currentChapter: Chapter?
        public var isLoading = true
        public var errorMessage: String?
        public var currentPageObject: Page?
        private var pageLoadTask: Task<Void, Never>?
        
        // Cache flag to prevent reloading on every view appearance
        private var hasLoadedData = false
        
        // Services
        private let realmService = RealmService.shared
        private let dataCache = QuranDataCacheService.shared
        
        public var showReadingSetting:Bool = false
        public var showReadingSettingsSheet:Bool = false
        public var showMushafTypePicker:Bool = false
        public var showBookmarsView:Bool = false
        public var showPageSlider:Bool = false
        public var showPlayingPanel:Bool = false
        public var showSearchPanel:Bool = false
        public var showShareOptions:Bool = false
        public var showTafsir:Bool = false
        
        public var contentOpacity:CGFloat {
            if showReadingSetting ||
           showReadingSettingsSheet ||
           showMushafTypePicker ||
           showBookmarsView ||
           showPageSlider ||
           showPlayingPanel ||
           showSearchPanel ||
           showShareOptions ||
               showTafsir {
                return 0.2
            }
            return 1.0
        }
        // MARK: - Initialization
        
        public init() {
            // Initialize with page 1
        }
        
        // MARK: - Data Loading
        
        @MainActor
        /// Load the chapters list and warm up the first page so the view can
        /// render without blocking on Realm I/O.
        public func loadData() async {
            // Skip loading if data is already cached
            if hasLoadedData {
                isLoading = false
                return
            }
            
            do {
                let cache = ChaptersDataCache.shared
                if !cache.isCached {
                    try await cache.loadAndCache()
                }
                chapters = cache.allChapters
                
                // Warm up current page data so the first render is instant
                currentPageObject = await realmService.fetchPageAsync(number: currentPage)
                updateCurrentChapter(for: currentPage)
                
                // Mark data as loaded to prevent reloading
                hasLoadedData = true
                isLoading = false
            } catch {
                errorMessage = "Failed to load Chapters: \(error.localizedDescription)"
                isLoading = false
            }
        }
        
        @MainActor
        /// Prime the Mushaf view with an initial page.
        public func initializePageView(initialPage: Int?) async {
            await loadData()
            
            if let page = initialPage {
                currentPage = page
            }
            
            // Set initial scroll position
            scrollPosition = currentPage
            
            // Show UI immediately - images load directly from bundle
            isInitialPageReady = true
        }
        
        // MARK: - Page Navigation
        
        @MainActor
        /// Derive the active chapter for a given page, keeping UI metadata in sync.
        public func updateCurrentChapter(for page: Int) {
            currentChapter = chapters.first { chapter in
                page >= chapter.startPage && page <= chapter.endPage
            }
        }
        
        public func navigateToChapter(_ chapter: Chapter) {
            currentPage = chapter.startPage
        }
        
        public func nextPage() {
            guard currentPage < 604 else { return }
            currentPage += 1
        }
        
        public func previousPage() {
            guard currentPage > 1 else { return }
            currentPage -= 1
        }
        
        public func goToPage(_ page: Int) {
            guard page >= 1 && page <= 604 else { return }
            currentPage = page
        }
        
        /// Navigate to chapter and set scroll position to its start page
        /// Jump to a chapter and update the scroll position so SwiftUI updates the pager.
        public func navigateToChapterAndPrepareScroll(_ chapter: Chapter) {
            navigateToChapter(chapter)
            scrollPosition = chapter.startPage
        }
        
        @MainActor
        private func schedulePageLoad(for page: Int) {
            pageLoadTask?.cancel()
            pageLoadTask = Task { @MainActor in
                let pageObject = await self.realmService.fetchPageAsync(number: page)
                if Task.isCancelled { return }
                self.currentPageObject = pageObject
                self.updateCurrentChapter(for: page)
                self.pageLoadTask = nil
            }
        }
        
        // MARK: - Navigation Logic
        
        @MainActor
        /// Update caches when the user scrolls to a new page.
        public func handlePageChange(from oldPage: Int?, to newPage: Int) async {
            guard oldPage != nil else {
                // First page load
                currentPage = newPage
                updateCurrentChapter(for: newPage)
                return
            }
            
            // Update current page and chapter
            currentPage = newPage
            updateCurrentChapter(for: newPage)
        }
        
        // MARK: - Chapter Navigation Helpers
        
        /// Get chapter by its number
        /// Lookup a chapter model by its numeric identifier.
        public func chapter(number: Int) -> Chapter? {
            return chapters.first(where: { $0.number == number })
        }
        
        /// Compute the next chapter number bounded by available chapters
        /// Compute the next chapter number ensuring we stay within valid bounds.
        public func nextChapterNumber(after current: Int) -> Int {
            let maxChapter = chapters.last?.number ?? 114
            return min(current + 1, maxChapter)
        }
        
        /// Compute the previous chapter number bounded by available chapters
        /// Compute the previous chapter number ensuring we stay within valid bounds.
        public func previousChapterNumber(before current: Int) -> Int {
            let minChapter = chapters.first?.number ?? 1
            return max(current - 1, minChapter)
        }
        
        /// Get the next chapter model relative to a chapter number
        /// Retrieve the `Chapter` object that follows the provided chapter number.
        public func nextChapter(from current: Int) -> Chapter? {
            return chapter(number: nextChapterNumber(after: current))
        }
        
        /// Get the previous chapter model relative to a chapter number
        /// Retrieve the `Chapter` object that precedes the provided chapter number.
        public func previousChapter(from current: Int) -> Chapter? {
            return chapter(number: previousChapterNumber(before: current))
        }
        
        // MARK: - UI Actions
                
        /// Get a specific verse from a chapter
        /// Resolve a verse using its chapter and verse numbers.
        public func getVerse(chapterNumber: Int, verseNumber: Int) -> Verse? {
            return realmService.getVerse(chapterNumber: chapterNumber, verseNumber: verseNumber)
        }
        
        /// Mark a verse as selected so downstream UI can show context menus or sheets.
        public func showVerseDetails(_ verse: Verse) {
            selectedVerse = verse  // Set the selected verse
            // No longer automatically present sheet - handled by action bar
        }
        
        /// Clear any modals or selections that were presenting verse details.
        public func closeVerseDetails() {
            presentedVerse = nil
            selectedVerse = nil  // Clear selection when closing
        }
        
        /// Deselect the currently highlighted verse.
        public func clearSelection() {
            selectedVerse = nil
        }
        
        // MARK: - Page Object Accessors
        
        /// Get verses for the current page (tries cache first, then falls back to Realm)
        /// Fetch verses for the current page from the in-memory cache or Realm.
        public func getVersesForCurrentPage(mushafType: MushafType = .hafs1441) -> [Verse] {
            // Try to get from cache first for better performance
            if let cachedVerses = dataCache.getCachedVerses(forPage: currentPage) {
                return cachedVerses
            }
            
            // Fall back to Realm
            guard let page = currentPageObject else { return [] }
            
            switch mushafType {
            case .hafs1441:
                return Array(page.verses1441)
            case .hafs1405:
                return Array(page.verses1405)
            }
        }
        
        /// Get chapter headers for the current page directly from Page object
        /// Access the header overlays for the current page for layout decisions.
        public func getChapterHeadersForCurrentPage(mushafType: MushafType = .hafs1441) -> [ChapterHeader] {
            guard let page = currentPageObject else { return [] }
            
            switch mushafType {
            case .hafs1441:
                return Array(page.chapterHeaders1441)
            case .hafs1405:
                return Array(page.chapterHeaders1405)
            }
        }
        
        /// Check if current page is a right page
        /// Indicates whether the current page should be rendered on the right side of the spread.
        public var isCurrentPageRight: Bool {
            return currentPageObject?.isRight ?? false
        }
        
        /// Get page number directly from Page object
        /// Resolve the current page number, falling back to the tracked state if the Realm object is missing.
        public var pageNumber: Int {
            return currentPageObject?.number ?? currentPage
        }
        
        /// Get page header info (tries cache first, then falls back to Realm)
        /// Return aggregated header metadata that feeds the header UI components.
        public func getPageHeaderInfo() -> PageHeaderInfo? {
            // Try to get from cache first
            if let cachedHeader = dataCache.getCachedPageHeader(forPage: currentPage) {
                return cachedHeader
            }
            
            // Fall back to Realm
            return realmService.getPageHeaderInfo(for: currentPage)
        }
    }
}

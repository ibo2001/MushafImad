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
        /// The verse currently presented in a modal sheet.
        public var presentedVerse: Verse?
        /// The verse the user last tapped, shown with context actions.
        public var selectedVerse: Verse?
        /// The verse queued for Tafsir display.
        public var tafsirVerse: Verse?
        /// Whether the initial page has finished loading and is ready to render.
        public var isInitialPageReady = false
        /// The page number the scroll view is currently anchored to.
        public var scrollPosition: Int?
        
        // Data State
        /// The page number currently in view; triggers a background page load on change.
        public var currentPage: Int = 1 {
            didSet {
                if currentPage != oldValue {
                    schedulePageLoad(for: currentPage)
                }
            }
        }
        /// All chapters loaded from the Realm database.
        public var chapters: [Chapter] = []
        /// The chapter that contains the current page.
        public var currentChapter: Chapter?
        /// Whether the initial data load is in progress.
        public var isLoading = true
        /// A human-readable description of any load failure.
        public var errorMessage: String?
        /// The Realm page object for the current page, populated asynchronously.
        public var currentPageObject: Page?
        private var pageLoadTask: Task<Void, Never>?
        
        // Cache flag to prevent reloading on every view appearance
        private var hasLoadedData = false
        private var cachedTotalPages: Int = 0
        
        // Services
        private let realmService: RealmService
        private let dataCache = QuranDataCacheService.shared
        
        /// Controls visibility of the reading-settings overlay.
        public var showReadingSetting:Bool = false
        /// Controls visibility of the reading-settings sheet.
        public var showReadingSettingsSheet:Bool = false
        /// Controls visibility of the Mushaf type picker.
        public var showMushafTypePicker:Bool = false
        /// Controls visibility of the bookmarks panel.
        public var showBookmarsView:Bool = false
        /// Controls visibility of the page-jump slider.
        public var showPageSlider:Bool = false
        /// Controls visibility of the audio player panel.
        public var showPlayingPanel:Bool = false
        /// Controls visibility of the search panel.
        public var showSearchPanel:Bool = false
        /// Controls visibility of the share options panel.
        public var showShareOptions:Bool = false
        /// Controls visibility of the Tafsir sheet.
        public var showTafsir:Bool = false
        
        /// Opacity of the main content; reduced to 0.2 when any overlay panel is visible.
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
        
        /// Creates a view model backed by the given Realm service.
        public init(realmService: RealmService = .shared) {
            self.realmService = realmService
        }
        
        /// Total number of pages; returns the cached value after data loads, falls back to a live Realm query.
        public var totalPages: Int {
            cachedTotalPages > 0 ? cachedTotalPages : realmService.getTotalPages()
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
                try await cache.loadAndCache(using: realmService)
                chapters = cache.allChapters
                
                // Warm up current page data so the first render is instant
                currentPageObject = await realmService.fetchPageAsync(number: currentPage)
                updateCurrentChapter(for: currentPage)
                
                // Mark data as loaded to prevent reloading
                cachedTotalPages = realmService.getTotalPages()
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
        
        /// Jumps the reader to the start page of the given chapter.
        public func navigateToChapter(_ chapter: Chapter) {
            currentPage = chapter.startPage
        }
        
        /// Advances to the next page if one exists.
        public func nextPage() {
            guard currentPage < totalPages else { return }
            currentPage += 1
        }
        
        /// Moves back to the previous page if one exists.
        public func previousPage() {
            guard currentPage > 1 else { return }
            currentPage -= 1
        }
        
        /// Navigates to an arbitrary page, clamped to valid bounds.
        public func goToPage(_ page: Int) {
            guard page >= 1 && page <= totalPages else { return }
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

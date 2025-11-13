//
//  QuranImageProvider.swift
//  MushafImad
//
//  Created by Assistant on 30/10/2025.
//

import Foundation
import UIKit
import Combine

/// High-level API for retrieving Quran line images for views.
@MainActor
public final class QuranImageProvider: ObservableObject {
    public static let shared = QuranImageProvider()

    private let fileStore: QuranImageFileStore
    private let downloader: QuranImageDownloadManager
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // Track which pages are currently being prefetched to avoid duplicates
    private var prefetchingPages = Set<Int>()

    private init(fileStore: QuranImageFileStore = .shared,
                 downloader: QuranImageDownloadManager = .shared) {
        self.fileStore = fileStore
        self.downloader = downloader
        // Increase cache to hold ~60 pages worth of images (60 * 15 = 900 lines)
        memoryCache.countLimit = 900
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100MB memory limit
    }

    public func image(page: Int, line: Int) async -> UIImage? {
        let key = cacheKey(page: page, line: line)
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        // Read from disk in a background task to avoid blocking UI
        let disk = await fileStore.readImage(page: page, line: line)
        
        if let disk = disk {
            // Estimate cost based on image size
            let cost = disk.pngData()?.count ?? 0
            memoryCache.setObject(disk, forKey: key as NSString, cost: cost)
            return disk
        }
        return nil
    }

    public func ensureAvailable(page: Int, line: Int) async {
        if await fileStore.exists(page: page, line: line) { return }
        do {
            _ = try await downloader.download(page: page, line: line)
            let img = await fileStore.readImage(page: page, line: line)
            
            if let img = img {
                let cost = img.pngData()?.count ?? 0
                memoryCache.setObject(img, forKey: cacheKey(page: page, line: line) as NSString, cost: cost)
                objectWillChange.send()
            }
        } catch {
            // Swallow; views can trigger retry
        }
    }

    /// Check if a page is fully cached in memory (all 15 lines)
    public func isPageCached(page: Int) -> Bool {
        for line in 1...15 {
            let key = cacheKey(page: page, line: line)
            if memoryCache.object(forKey: key as NSString) == nil {
                return false
            }
        }
        return true
    }
    
    /// Aggressively prefetch and cache images for a page and its neighbors
    public func prefetchWithNeighbors(currentPage: Int) {
        let pagesToPrefetch = [
            currentPage - 1,
            currentPage,
            currentPage + 1
        ].filter { $0 >= 1 && $0 <= 604 }
        
        for page in pagesToPrefetch {
            prefetch(page: page)
        }
    }
    
    /// Wait for a specific page to be fully loaded into memory cache
    public func waitForPageReady(page: Int) async {
        // If already cached, return immediately
        if isPageCached(page: page) {
            return
        }
        
        // Otherwise, prefetch with high priority and wait
        guard !prefetchingPages.contains(page) else {
            // Already prefetching, wait for it to complete
            while prefetchingPages.contains(page) {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
            return
        }
        
        prefetchingPages.insert(page)
        
        // Download files if needed
        await downloader.prefetch(page: page)
        
        // Load all lines into memory cache with high priority
        let fileStore = self.fileStore
        
        for line in 1...15 {
            if let img = await fileStore.readImage(page: page, line: line) {
                let key = "\(page)-\(line)" as NSString
                let cost = img.pngData()?.count ?? 0
                memoryCache.setObject(img, forKey: key, cost: cost)
            }
        }
        
        prefetchingPages.remove(page)
    }
    
    public func prefetch(page: Int) {
        guard !prefetchingPages.contains(page) else { return }
        prefetchingPages.insert(page)
        
        Task { @MainActor in
            // Download files if needed (background priority)
            await downloader.prefetch(page: page)
            
            let fileStore = self.fileStore
            
            for line in 1...15 {
                if let img = await fileStore.readImage(page: page, line: line) {
                    let key = "\(page)-\(line)" as NSString
                    let cost = img.pngData()?.count ?? 0
                    memoryCache.setObject(img, forKey: key, cost: cost)
                }
            }
            
            prefetchingPages.remove(page)
        }
    }

    private func cacheKey(page: Int, line: Int) -> String { "\(page)-\(line)" }

    /// Override the remote base URL used for downloading images.
    public func updateImageBaseURL(_ url: URL) async {
        await downloader.updateBaseURL(url)
        memoryCache.removeAllObjects()
        prefetchingPages.removeAll()
    }

    /// Reset the remote base URL back to the package default.
    public func resetImageBaseURLToDefault() async {
        await downloader.resetBaseURLToDefault()
        memoryCache.removeAllObjects()
        prefetchingPages.removeAll()
    }

    /// Inspect the current remote base URL.
    public func currentImageBaseURL() async -> URL {
        await downloader.currentBaseURL()
    }

    /// Download every Mushaf page line-by-line. Call this during onboarding when you need
    /// the full dataset available before showing any UI.
    public func preloadEntireMushaf(progress: (@Sendable (Int, Int) -> Void)? = nil) async throws {
        try await downloader.downloadEntireMushaf(progress: progress)
    }
}

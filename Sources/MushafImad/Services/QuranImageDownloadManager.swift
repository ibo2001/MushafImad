//
//  QuranImageDownloadManager.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

import Foundation

/// Actor responsible for downloading Quran line images and storing them on disk.
public actor QuranImageDownloadManager {
    public static let shared = QuranImageDownloadManager()

    private let fileStore: QuranImageFileStore
    private let session: URLSession

    /// Limit concurrent network requests
    private let maxConcurrentDownloads = 6
    private var currentDownloadsCount = 0

    /// Deduplicate in-flight downloads per line id ("page:line")
    private var inFlightTasks: [String: Task<URL, Error>] = [:]

    /// Base URL format: {baseURL}/{page}/{line}.png
    private static let defaultBaseURL = URL(string: "https://mushaf-imad.qraiqe.no/files/data/quran-images")!
    private var baseURL: URL

    public init(fileStore: QuranImageFileStore = .shared,
                session: URLSession = .shared,
                baseURL: URL? = nil) {
        self.fileStore = fileStore
        self.session = session
        self.baseURL = baseURL ?? Self.defaultBaseURL
    }

    // MARK: - Public API

    public func download(page: Int, line: Int) async throws -> URL {
        // If already on disk, return immediately
        if await fileStore.exists(page: page, line: line) {
            return try await fileStore.fileURL(forPage: page, line: line)
        }

        let key = "\(page):\(line)"
        if let task = inFlightTasks[key] {
            return try await task.value
        }

        let task = Task { () throws -> URL in
            // Concurrency gate
            try await acquireDownloadSlot()
            defer { releaseDownloadSlot() }

            let url = try makeRemoteURL(page: page, line: line)
            let data = try await downloadWithRetry(from: url)
            try await fileStore.writeAtomically(data: data, page: page, line: line)
            return try await fileStore.fileURL(forPage: page, line: line)
        }

        inFlightTasks[key] = task
        do {
            let result = try await task.value
            removeInFlight(forKey: key)
            return result
        } catch {
            removeInFlight(forKey: key)
            throw error
        }
    }

    public func prefetch(page: Int) {
        // Fire-and-forget low priority tasks for all 15 lines
        for line in 1...15 {
            Task(priority: .background) {
                _ = try? await download(page: page, line: line)
            }
        }
    }

    public func updateBaseURL(_ url: URL) {
        baseURL = url
    }

    public func currentBaseURL() -> URL {
        baseURL
    }

    public func resetBaseURLToDefault() {
        baseURL = Self.defaultBaseURL
    }

    public func downloadEntireMushaf(progress: (@Sendable (Int, Int) -> Void)? = nil) async throws {
        let totalLines = 604 * 15
        var completed = 0

        for page in 1...604 {
            for line in 1...15 {
                try Task.checkCancellation()
                try await download(page: page, line: line)
                completed += 1
                if let progress {
                    await MainActor.run {
                        progress(completed, totalLines)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func makeRemoteURL(page: Int, line: Int) throws -> URL {
        baseURL
            .appendingPathComponent("\(page)")
            .appendingPathComponent("\(line).png")
    }

    private func acquireDownloadSlot() async throws {
        while currentDownloadsCount >= maxConcurrentDownloads {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        currentDownloadsCount += 1
    }

    private func releaseDownloadSlot() {
        currentDownloadsCount = max(0, currentDownloadsCount - 1)
    }

    private func removeInFlight(forKey key: String) {
        inFlightTasks.removeValue(forKey: key)
    }

    private func downloadWithRetry(from url: URL) async throws -> Data {
        var attempt = 0
        let maxAttempts = 3
        var lastError: Error?

        while attempt < maxAttempts {
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw NSError(domain: "QuranImageDownloadManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected status code"])
                }
                // Basic PNG signature check (optional, lightweight)
                if data.count >= 8 {
                    let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
                    let header = Array(data.prefix(8))
                    if header.elementsEqual(pngMagic) == false {
                        throw NSError(domain: "QuranImageDownloadManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Not a PNG file"])
                    }
                }
                return data
            } catch {
                lastError = error
                attempt += 1
                if attempt >= maxAttempts { break }
                // Exponential backoff: 0.5s, 1s, 2s
                let delay: UInt64 = 500_000_000 << (attempt - 1)
                try? await Task.sleep(nanoseconds: delay)
            }
        }

        throw lastError ?? NSError(domain: "QuranImageDownloadManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unknown download error"])
    }
}



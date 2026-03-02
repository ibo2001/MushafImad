import Foundation

/// Loads and indexes JSON timing files so audio playback can align with verses.
@MainActor
public final class AyahTimingService {
    public static let shared = AyahTimingService()
    
    private var reciterTimings: [Int: ReciterTiming] = [:]
    private var timingMaps: [Int: [Int: [Int: (start: Int, end: Int)]]] = [:]
    private var attemptedLocalTimingLoads: Set<Int> = []
    private let timingManager = TimingManager()
    private var remoteAudioURLs: [Int: [Int: URL]] = [:]
    private var itqanTimingCache: [String: [Int: (start: Int, end: Int)]] = [:]
    private var inFlightRefreshTasks: [String: Task<(chapterMap: [Int: (start: Int, end: Int)], audioURL: URL?), Never>] = [:]
    
    private init() {}
    
    private func loadTiming(for reciterId: Int) {
        if reciterTimings[reciterId] != nil || attemptedLocalTimingLoads.contains(reciterId) { return }
        attemptedLocalTimingLoads.insert(reciterId)
        
        let fileName = "read_\(reciterId)"
        
        // Try multiple ways to find the file
        var url: URL? = nil
        
        // Method 1: Try with subdirectory
        url = Bundle.mushafResources.url(forResource: fileName, withExtension: "json", subdirectory: "ayah_timing")
        
        // Method 2: Try without subdirectory
        if url == nil {
            url = Bundle.mushafResources.url(forResource: fileName, withExtension: "json")
        }
        
        // Method 3: Try with full path
        if url == nil {
            url = Bundle.mushafResources.url(forResource: "ayah_timing/\(fileName)", withExtension: "json")
        }
        
        // Method 4: Try to find in Resources folder
        if url == nil {
            url = Bundle.mushafResources.url(forResource: "Res/ayah_timing/\(fileName)", withExtension: "json")
        }
        
        if let url = url {
            do {
                let data = try Data(contentsOf: url)
                let reciter = try JSONDecoder().decode(ReciterTiming.self, from: data)
                reciterTimings[reciterId] = reciter
                
                var map: [Int: [Int: (Int, Int)]] = [:]
                for chapter in reciter.chapters {
                    var chapterMap: [Int: (Int, Int)] = [:]
                    for timing in chapter.aya_timing {
                        chapterMap[timing.ayah] = (timing.start_time, timing.end_time)
                    }
                    map[chapter.id] = chapterMap
                }
                if let existingMap = timingMaps[reciterId] {
                    // Preserve any chapters refreshed from remote providers.
                    for (chapterId, chapterTimings) in existingMap {
                        map[chapterId] = chapterTimings
                    }
                }
                timingMaps[reciterId] = map
            } catch {
                AppLogger.shared.error("AyahTimingService: Error loading timing for reciter \(reciterId): \(error)",category: .network)
            }
        } else {
            AppLogger.shared.error("AyahTimingService: Could not find JSON file for reciter \(reciterId)",category: .network)
            AppLogger.shared.error("AyahTimingService: Searched for: \(fileName).json",category: .network)
        }
    }
    
    public func getTiming(for reciterId: Int, surahId: Int, ayahId: Int) -> (start: Int, end: Int)? {
        loadTiming(for: reciterId)
        return timingMaps[reciterId]?[surahId]?[ayahId]
    }

    /// Refreshes remote chapter timing when supported by the reciter timing source
    /// and updates the local in-memory map used by playback controls.
    public func refreshChapterTimings(for reciterId: Int, surahId: Int) async -> URL? {
        let source = await timingManager.timingSource(for: reciterId)
        switch source {
        case .mp3quran, .none:
            loadTiming(for: reciterId)
            return nil
        case .itqan:
            return await refreshRemoteChapterTimings(for: reciterId, surahId: surahId)
        case .both:
            _ = await refreshRemoteChapterTimings(for: reciterId, surahId: surahId)
            return nil
        }
    }

    public func getRemoteAudioURL(for reciterId: Int, surahId: Int) -> URL? {
        remoteAudioURLs[reciterId]?[surahId]
    }

    private func refreshRemoteChapterTimings(for reciterId: Int, surahId: Int) async -> URL? {
        let chapterKey = "\(reciterId)-\(surahId)"

        if let cached = itqanTimingCache[chapterKey] {
            var reciterMap = timingMaps[reciterId] ?? [:]
            reciterMap[surahId] = cached
            timingMaps[reciterId] = reciterMap
            return remoteAudioURLs[reciterId]?[surahId]
        }

        // Reuse existing in-flight task to avoid duplicate network requests.
        if let existingTask = inFlightRefreshTasks[chapterKey] {
            let result = await existingTask.value
            applyRemoteChapterResult(reciterId: reciterId, surahId: surahId, chapterMap: result.chapterMap, audioURL: result.audioURL)
            return result.audioURL
        }

        let refreshTask = Task<(chapterMap: [Int: (start: Int, end: Int)], audioURL: URL?), Never> {
            do {
                guard let chapterData = try await timingManager.refreshRemoteTimingIfAvailable(reciterId: reciterId, surahId: surahId),
                      !chapterData.timings.isEmpty else {
                    return ([:], nil)
                }

                var chapterMap: [Int: (start: Int, end: Int)] = [:]
                for timing in chapterData.timings {
                    chapterMap[timing.ayahId] = (
                        Int((timing.startTime * 1000.0).rounded()),
                        Int((timing.endTime * 1000.0).rounded())
                    )
                }
                return (chapterMap, chapterData.audioURL)
            } catch {
                AppLogger.shared.warn(
                    "AyahTimingService: Remote timing refresh failed for reciter \(reciterId), surah \(surahId): \(error.localizedDescription)",
                    category: .network
                )
                return ([:], nil)
            }
        }

        inFlightRefreshTasks[chapterKey] = refreshTask
        let result = await refreshTask.value
        inFlightRefreshTasks[chapterKey] = nil

        applyRemoteChapterResult(reciterId: reciterId, surahId: surahId, chapterMap: result.chapterMap, audioURL: result.audioURL)
        return result.audioURL
    }

    private func applyRemoteChapterResult(
        reciterId: Int,
        surahId: Int,
        chapterMap: [Int: (start: Int, end: Int)],
        audioURL: URL?
    ) {
        guard !chapterMap.isEmpty else { return }

        let chapterKey = "\(reciterId)-\(surahId)"
        itqanTimingCache[chapterKey] = chapterMap

        var reciterMap = timingMaps[reciterId] ?? [:]
        reciterMap[surahId] = chapterMap
        timingMaps[reciterId] = reciterMap

        if let audioURL {
            var reciterAudioMap = remoteAudioURLs[reciterId] ?? [:]
            reciterAudioMap[surahId] = audioURL
            remoteAudioURLs[reciterId] = reciterAudioMap
        }
    }
    
    public func getReciter(id: Int) -> ReciterTiming? {
        loadTiming(for: id)
        return reciterTimings[id]
    }
    
    public func getAllAvailableReciters() -> [ReciterTiming] {
        let reciterIds = [1, 5, 9, 10, 31, 32, 51, 53, 60, 62, 67, 74, 78, 106, 112, 118, 159, 256]
        var reciters: [ReciterTiming] = []
        
        for id in reciterIds {
            if let reciter = getReciter(id: id) {
                reciters.append(reciter)
            }
        }
        
        return reciters
    }
    
    /// Get the current verse number based on playback time (in milliseconds)
    public func getCurrentVerse(for reciterId: Int, surahId: Int, currentTimeMs: Int) -> Int? {
        loadTiming(for: reciterId)

        guard let chapterMap = timingMaps[reciterId]?[surahId], !chapterMap.isEmpty else {
            return nil
        }

        let timings = chapterMap.map { (ayah: $0.key, start: $0.value.start, end: $0.value.end) }

        // Some timing JSON files appear to have ~+10ms on verse start times.
        // Apply a small negative offset so verse highlighting aligns with playback.
        let startTimeCorrectionMs = 10

        // Find the verse that contains the current time
        // Iterate in reverse so we prefer the later verse at boundaries/overlaps
        for timing in timings.sorted(by: { $0.start > $1.start }) {
            let adjustedStart = max(0, timing.start - startTimeCorrectionMs)
            if currentTimeMs >= adjustedStart && currentTimeMs <= timing.end {
                return timing.ayah
            }
        }

        // If we're past all verses, return the last verse
        if let lastVerse = timings.max(by: { $0.end < $1.end }),
           currentTimeMs > lastVerse.end {
            return lastVerse.ayah
        }

        return nil
    }
    
    /// Get all verse timings for a chapter
    public func getChapterTimings(for reciterId: Int, surahId: Int) -> [(ayah: Int, start: Int, end: Int)]? {
        loadTiming(for: reciterId)

        guard let chapterMap = timingMaps[reciterId]?[surahId], !chapterMap.isEmpty else {
            return nil
        }

        return chapterMap
            .map { (ayah: $0.key, start: $0.value.start, end: $0.value.end) }
            .sorted { $0.ayah < $1.ayah }
    }
}

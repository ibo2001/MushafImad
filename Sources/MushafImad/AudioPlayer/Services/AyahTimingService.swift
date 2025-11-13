import Foundation

/// Loads and indexes JSON timing files so audio playback can align with verses.
@MainActor
public final class AyahTimingService {
    public static let shared = AyahTimingService()
    
    private var reciterTimings: [Int: ReciterTiming] = [:]
    private var timingMaps: [Int: [Int: [Int: (start: Int, end: Int)]]] = [:]
    
    private init() {}
    
    private func loadTiming(for reciterId: Int) {
        if reciterTimings[reciterId] != nil { return }
        
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
        
        // Get the chapter timing data
        guard let reciter = reciterTimings[reciterId],
              let chapter = reciter.chapters.first(where: { $0.id == surahId }) else {
            return nil
        }
        
        // Some timing JSON files appear to have ~+10ms on verse start times.
        // Apply a small negative offset so verse highlighting aligns with playback.
        let startTimeCorrectionMs = 10

        // Find the verse that contains the current time
        // Iterate in reverse so we prefer the later verse at boundaries/overlaps
        for timing in chapter.aya_timing.reversed() {
            let adjustedStart = max(0, timing.start_time - startTimeCorrectionMs)
            if currentTimeMs >= adjustedStart && currentTimeMs <= timing.end_time {
                return timing.ayah
            }
        }
        
        // If we're past all verses, return the last verse
        if let lastVerse = chapter.aya_timing.last,
           currentTimeMs > lastVerse.end_time {
            return lastVerse.ayah
        }
        
        return nil
    }
    
    /// Get all verse timings for a chapter
    public func getChapterTimings(for reciterId: Int, surahId: Int) -> [(ayah: Int, start: Int, end: Int)]? {
        loadTiming(for: reciterId)
        
        guard let reciter = reciterTimings[reciterId],
              let chapter = reciter.chapters.first(where: { $0.id == surahId }) else {
            return nil
        }
        
        return chapter.aya_timing.map { (ayah: $0.ayah, start: $0.start_time, end: $0.end_time) }
    }
}

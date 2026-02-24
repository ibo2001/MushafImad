import Foundation

/// Adapter around the bundled MP3Quran timing JSON files.
struct Mp3QuranTimingProvider: VerseTimingProvider {
    func fetchChapterData(for reciterId: Int, surahId: Int) async throws -> ChapterTimingData {
        guard let url = timingFileURL(for: reciterId) else {
            throw TimingProviderError.missingData
        }

        let data = try Data(contentsOf: url)
        let reciter = try JSONDecoder().decode(ReciterTiming.self, from: data)
        guard let chapter = reciter.chapters.first(where: { $0.id == surahId }) else {
            throw TimingProviderError.missingData
        }

        let timings = chapter.aya_timing.map { ayah in
            VerseTiming(
                surahId: surahId,
                ayahId: ayah.ayah,
                startTime: Double(ayah.start_time) / 1000.0,
                endTime: Double(ayah.end_time) / 1000.0
            )
        }

        guard !timings.isEmpty else {
            throw TimingProviderError.missingData
        }
        return ChapterTimingData(timings: timings, audioURL: nil)
    }

    private func timingFileURL(for reciterId: Int) -> URL? {
        let fileName = "read_\(reciterId)"

        return Bundle.mushafResources.url(forResource: fileName, withExtension: "json", subdirectory: "ayah_timing")
            ?? Bundle.mushafResources.url(forResource: fileName, withExtension: "json")
            ?? Bundle.mushafResources.url(forResource: "ayah_timing/\(fileName)", withExtension: "json")
            ?? Bundle.mushafResources.url(forResource: "Res/ayah_timing/\(fileName)", withExtension: "json")
    }
}

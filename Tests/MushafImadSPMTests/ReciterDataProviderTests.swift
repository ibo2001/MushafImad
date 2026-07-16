import Foundation
import Testing
@testable import MushafImad

/// `ReciterDataProvider.reciters` is the fallback catalog used only when no reciter can be
/// loaded from the bundled `ayah_timing` JSON, so it cannot read that JSON itself and has to
/// duplicate the values. These tests pin the duplicated values to the JSON they mirror; without
/// them the two drift apart silently and the fallback serves wrong names and audio URLs.
@Suite
@MainActor
struct ReciterDataProviderTests {

    /// Entries backed by a bundled `read_<id>.json`. Itqan-only reciters (ids >= 1000) have no
    /// timing file and are excluded.
    private var jsonBackedEntries: [(entry: ReciterCatalogEntry, timing: ReciterTiming)] {
        ReciterDataProvider.reciters.compactMap { entry in
            guard let timing = AyahTimingService.shared.getReciter(id: entry.id) else { return nil }
            return (entry, timing)
        }
    }

    @Test
    func everyManifestReciterResolvesToBundledTiming() {
        let resolved = jsonBackedEntries.map(\.entry.id)
        let expected = ReciterDataProvider.reciters.filter { $0.id < 1000 }.map(\.id)
        #expect(resolved.sorted() == expected.sorted(),
                "Reciters missing bundled timing JSON: \(Set(expected).subtracting(resolved).sorted())")
    }

    @Test
    func fallbackFolderURLsMatchBundledTiming() {
        for (entry, timing) in jsonBackedEntries {
            #expect(entry.folderURL == timing.folder_url,
                    "id \(entry.id): folderURL \(entry.folderURL) != JSON \(timing.folder_url)")
        }
    }

    @Test
    func fallbackNamesMatchBundledTiming() {
        for (entry, timing) in jsonBackedEntries {
            #expect(entry.nameArabic == timing.name,
                    "id \(entry.id): nameArabic \(entry.nameArabic) != JSON \(timing.name)")
            #expect(entry.nameEnglish == timing.name_en,
                    "id \(entry.id): nameEnglish \(entry.nameEnglish) != JSON \(timing.name_en)")
            #expect(entry.rewaya == timing.rewaya,
                    "id \(entry.id): rewaya \(entry.rewaya) != JSON \(timing.rewaya)")
        }
    }

    /// A wrong Arabic/English pairing is how id 112 ended up labelled Al-Banna while pointing at
    /// Al-Minshawi's audio, which no per-field check against a single entry would catch.
    @Test
    func reciterIdentitiesAreUnique() {
        let ids = ReciterDataProvider.reciters.map(\.id)
        #expect(Set(ids).count == ids.count, "Duplicate reciter ids in catalog")
    }
}

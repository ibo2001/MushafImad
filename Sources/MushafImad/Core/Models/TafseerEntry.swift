//
//  TafseerEntry.swift
//  MushafImad
//
//  Tafseer Al-Jalalayn data model stored in a dedicated local Realm database.
//

import Foundation
import RealmSwift

/// A single ayah-level Tafseer record stored locally for offline access.
public final class TafseerEntry: Object, Identifiable {

    /// Composite primary key: "<tafseerName>_<surahId>_<ayahId>", e.g. "jalalayn_1_1"
    @Persisted(primaryKey: true) public var identifier: String = ""

    /// Surah (chapter) number — 1-indexed, 1-114.
    @Persisted public var surahId: Int = 0

    /// Ayah (verse) number within the surah — 1-indexed.
    @Persisted public var ayahId: Int = 0

    /// Global sequential ayah number across the full Mushaf (1-6236).
    @Persisted public var globalAyahNumber: Int = 0

    /// Tafseer text in Arabic.
    @Persisted public var text: String = ""

    /// Identifier of the tafseer edition (e.g. "jalalayn").
    @Persisted public var tafseerName: String = ""

    // MARK: - Identifiable

    public var id: String { identifier }

    // MARK: - Convenience init

    convenience init(
        surahId: Int,
        ayahId: Int,
        globalAyahNumber: Int,
        text: String,
        tafseerName: String = "jalalayn"
    ) {
        self.init()
        self.surahId = surahId
        self.ayahId = ayahId
        self.globalAyahNumber = globalAyahNumber
        self.text = text
        self.tafseerName = tafseerName
        self.identifier = "\(tafseerName)_\(surahId)_\(ayahId)"
    }
}

// MARK: - Codable DTOs for alquran.cloud JSON parsing

/// Top-level wrapper returned by `GET /v1/quran/ar.jalalayn`.
struct AlQuranTafseerResponse: Codable {
    let code: Int
    let data: AlQuranTafseerData
}

struct AlQuranTafseerData: Codable {
    let surahs: [AlQuranSurah]
}

struct AlQuranSurah: Codable {
    let number: Int
    let ayahs: [AlQuranAyah]
}

struct AlQuranAyah: Codable {
    let number: Int           // global ayah number
    let numberInSurah: Int    // ayah number within the surah
    let text: String          // tafseer text
}

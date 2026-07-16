//
//  TafseerTests.swift
//  MushafImadTests
//
//  Tests for the Tafseer feature:
//    - TafseerEntry model correctness
//    - TafseerImportState helper computed properties
//    - TafseerService validation constants
//

import Testing
import RealmSwift
@testable import MushafImad

// MARK: - TafseerEntry model tests

@Test("TafseerEntry primary key is composed correctly")
func tafseerEntryPrimaryKey() {
    let entry = TafseerEntry(surahId: 2, ayahId: 255, globalAyahNumber: 262, text: "آية الكرسي", tafseerName: "jalalayn")
    #expect(entry.identifier == "jalalayn_2_255")
    #expect(entry.surahId == 2)
    #expect(entry.ayahId == 255)
    #expect(entry.globalAyahNumber == 262)
    #expect(entry.tafseerName == "jalalayn")
}

@Test("TafseerEntry stores text correctly")
func tafseerEntryText() {
    let sampleText = "بسم الله الرحمن الرحيم – تفسير الجلالين"
    let entry = TafseerEntry(surahId: 1, ayahId: 1, globalAyahNumber: 1, text: sampleText)
    #expect(entry.text == sampleText)
}

@Test("TafseerEntry default tafseerName is jalalayn")
func tafseerDefaultName() {
    let entry = TafseerEntry(surahId: 1, ayahId: 1, globalAyahNumber: 1, text: "text")
    #expect(entry.tafseerName == "jalalayn")
}

@Test("TafseerEntry Identifiable id matches identifier")
func tafseerEntryIdentifiable() {
    let entry = TafseerEntry(surahId: 114, ayahId: 6, globalAyahNumber: 6236, text: "text")
    #expect(entry.id == entry.identifier)
    #expect(entry.identifier == "jalalayn_114_6")
}

// MARK: - TafseerImportState helpers

@Test("TafseerImportState.ready isReady returns true")
func importStateReady() {
    let state = TafseerImportState.ready
    #expect(state.isReady == true)
    #expect(state.isFailed == false)
    #expect(state.isLoading == false)
}

@Test("TafseerImportState.fetching isLoading returns true")
func importStateFetching() {
    let state = TafseerImportState.fetching
    #expect(state.isReady == false)
    #expect(state.isFailed == false)
    #expect(state.isLoading == true)
}

@Test("TafseerImportState.importing isLoading returns true")
func importStateImporting() {
    let state = TafseerImportState.importing(progress: 0.5)
    #expect(state.isLoading == true)
    #expect(state.progressValue == 0.5)
}

@Test("TafseerImportState.failed isFailed returns true")
func importStateFailed() {
    let state = TafseerImportState.failed(.invalidData)
    #expect(state.isFailed == true)
    #expect(state.isReady == false)
    #expect(state.isLoading == false)
}

@Test("TafseerImportState.idle progressValue returns 0.0")
func importStateIdleProgress() {
    let state = TafseerImportState.idle
    #expect(state.progressValue == 0.0)
}

@Test("TafseerImportState.ready progressValue returns 1.0")
func importStateReadyProgress() {
    let state = TafseerImportState.ready
    #expect(state.progressValue == 1.0)
}

// MARK: - TafseerService validation constants

@Test("TafseerService expected ayah count is standard Mushaf count")
func tafseerExpectedAyahCount() {
    // The Quran has exactly 6,236 ayahs in the standard Hafs Mushaf. A wrong constant here
    // makes needsImport() accept a truncated download as complete.
    #expect(TafseerService.expectedAyahCount == 6236)
}

@Test("Surah verse counts total 6236")
func surahVerseCountsTotal() {
    // MushafTextView sizes its placeholder from this table, so a wrong length is both a layout
    // bug and, before the bounds check, a crash on the tail surahs. 114 surahs totalling 6,236
    // ayahs (Hafs 'an 'Asim) pins it against a typo in any entry.
    #expect(SurahVerseCounts.all.count == 114)
    #expect(SurahVerseCounts.all.reduce(0, +) == 6236)
    #expect(SurahVerseCounts.count(forSurah: 1) == 7)     // Al-Fatiha
    #expect(SurahVerseCounts.count(forSurah: 114) == 6)   // An-Nas
    #expect(SurahVerseCounts.count(forSurah: 0) == nil)
    #expect(SurahVerseCounts.count(forSurah: 115) == nil)
}

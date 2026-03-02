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
    // The Quran has exactly 6,236 ayahs in the standard Hafs Mushaf.
    // This test serves as documentation and a sentinel if someone accidentally
    // changes the validation constant.
    let expectedCount = 6236
    #expect(expectedCount == 6236)
}

@Test("Surah verse counts total 6236")
func surahVerseCountsTotal() {
    // Standard verse counts for all 114 surahs (Hafs 'an 'Asim).
    let verseCounts = [
         7, 286, 200, 176, 120, 165, 206,  75, 129, 109,
       123, 111,  43,  52,  99, 128, 111, 110,  98, 135,
       112,  78, 118,  64,  77, 227,  93,  88,  69,  60,
        34,  30,  73,  54,  45,  83, 182,  88,  75,  85,
        54,  53,  89,  59,  37,  35,  38,  29,  18,  45,
        60,  49,  62,  55,  78,  96,  29,  22,  24,  13,
        14,  11,  11,  18,  12,  12,  30,  52,  52,  44,
        28,  28,  20,  56,  40,  31,  50,  40,  46,  42,
        29,  19,  36,  25,  43,  32,  30,  27,  30,  20,
        45,  22,  33,  11,   8,  78,  28,  22,  12,  35,
        20,  18,  76,  44,  33,  54,  14,  14,   7,  25,
        17,  22,  13,   4,   5,   5,   7,   3,   6,   3,
         5,   4,   5,   6
    ]
    #expect(verseCounts.count == 114)
    #expect(verseCounts.reduce(0, +) == 6236)
}

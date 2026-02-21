//
//  ChapterGroup.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 31/10/2025.
//

import Foundation

/// Groups chapters that belong to a single juz' (part) of the Quran.
public struct ChaptersByPart: Identifiable {
    public let id: Int
    public let partNumber: Int
    public let arabicTitle: String
    public let englishTitle: String
    public let chapters: [Chapter]
    public let firstPage: Int?
    public let firstVerse: Verse?

    /// Creates a juz' grouping with the given metadata and chapters.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this part (equals `partNumber`).
    ///   - partNumber: The 1-based juz' number (1–30).
    ///   - arabicTitle: Localised Arabic title of the juz'.
    ///   - englishTitle: Localised English title of the juz'.
    ///   - chapters: Chapters that belong to this juz'.
    ///   - firstPage: Page number (1441-page edition) where this juz' begins.
    ///   - firstVerse: First verse of this juz', used for navigation.
    public init(
        id: Int,
        partNumber: Int,
        arabicTitle: String,
        englishTitle: String,
        chapters: [Chapter],
        firstPage: Int?,
        firstVerse: Verse?
    ) {
        self.id = id
        self.partNumber = partNumber
        self.arabicTitle = arabicTitle
        self.englishTitle = englishTitle
        self.chapters = chapters
        self.firstPage = firstPage
        self.firstVerse = firstVerse
    }
}

/// Groups chapters that fall within a single rub' hizb (quarter of a hizb).
public struct ChaptersByQuarter: Identifiable {
    public let id: Int
    public let quarterNumber: Int
    public let hizbNumber: Int
    public let hizbFraction: Int
    public let arabicTitle: String
    public let englishTitle: String
    public let chapters: [Chapter]
    public let firstPage: Int?
    public let firstVerse: Verse?

    /// Creates a quarter grouping with the given hizb metadata and chapters.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this quarter (equals `quarterNumber`).
    ///   - quarterNumber: The 1-based global quarter number.
    ///   - hizbNumber: The 1-based hizb number this quarter belongs to.
    ///   - hizbFraction: The position within the hizb (0–3, where 0 = fourth quarter).
    ///   - arabicTitle: Localised Arabic title for this quarter.
    ///   - englishTitle: Localised English title for this quarter.
    ///   - chapters: Chapters that have at least one verse in this quarter.
    ///   - firstPage: Page number (1441-page edition) where this quarter begins.
    ///   - firstVerse: First verse of this quarter, used for navigation.
    public init(
        id: Int,
        quarterNumber: Int,
        hizbNumber: Int,
        hizbFraction: Int,
        arabicTitle: String,
        englishTitle: String,
        chapters: [Chapter],
        firstPage: Int?,
        firstVerse: Verse?
    ) {
        self.id = id
        self.quarterNumber = quarterNumber
        self.hizbNumber = hizbNumber
        self.hizbFraction = hizbFraction
        self.arabicTitle = arabicTitle
        self.englishTitle = englishTitle
        self.chapters = chapters
        self.firstPage = firstPage
        self.firstVerse = firstVerse
    }
}

/// Groups all four quarters that make up a single hizb.
public struct ChaptersByHizb: Identifiable {
    public let id: Int
    public let hizbNumber: Int
    public let quarters: [ChaptersByQuarter]

    /// Creates a hizb grouping from its constituent quarters.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this hizb (equals `hizbNumber`).
    ///   - hizbNumber: The 1-based hizb number (1–60).
    ///   - quarters: The four `ChaptersByQuarter` values that form this hizb.
    public init(id: Int, hizbNumber: Int, quarters: [ChaptersByQuarter]) {
        self.id = id
        self.hizbNumber = hizbNumber
        self.quarters = quarters
    }

    /// A formatted Arabic title for this hizb (e.g., "الحزب ١").
    public var hizbTitle: String {
        hizbNumber.quarterTitle
    }
}

/// Groups chapters by their revelation type — Meccan or Medinan.
public struct ChaptersByType: Identifiable {
    public let id: String
    public let type: String
    public let arabicType: String
    public let chapters: [Chapter]
    public let firstPage: Int?
    public let firstVerse: Verse?

    /// Creates a type grouping with the given revelation type and chapters.
    ///
    /// - Parameters:
    ///   - id: Stable string identifier — `"meccan"` or `"medinan"`.
    ///   - type: English name of the revelation type.
    ///   - arabicType: Arabic name of the revelation type.
    ///   - chapters: Chapters belonging to this revelation type.
    ///   - firstPage: Page number (1441-page edition) of the first chapter in the group.
    ///   - firstVerse: First verse of the group, used for navigation.
    public init(
        id: String,
        type: String,
        arabicType: String,
        chapters: [Chapter],
        firstPage: Int?,
        firstVerse: Verse?
    ) {
        self.id = id
        self.type = type
        self.arabicType = arabicType
        self.chapters = chapters
        self.firstPage = firstPage
        self.firstVerse = firstVerse
    }

    /// Whether this grouping represents Meccan chapters.
    ///
    /// Returns `true` when `id == "meccan"`, `false` for Medinan chapters.
    public var isMeccan: Bool {
        id == "meccan"
    }
}


// MARK: - Mock Data Extensions

extension ChaptersByQuarter {
    /// Prebuilt test fixture representing the first quarter of Hizb 1.
    public static var mockFirstQuarter: ChaptersByQuarter {
        let chapter = Chapter()
        chapter.number = 1
        chapter.arabicTitle = "الفاتحة"
        chapter.englishTitle = "Al-Fatihah"
        
        let verse = Verse()
        verse.verseID = 1
        verse.number = 1
        verse.text = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"
        verse.chapter = chapter
        
        let page = Page()
        page.number = 1
        verse.page1441 = page
        
        return ChaptersByQuarter(
            id: 1,
            quarterNumber: 1,
            hizbNumber: 1,
            hizbFraction: 1,
            arabicTitle: "الربع الأول",
            englishTitle: "First Quarter",
            chapters: [chapter],
            firstPage: 1,
            firstVerse: verse
        )
    }
    
    /// Prebuilt test fixture representing the second quarter of Hizb 1.
    public static var mockSecondQuarter: ChaptersByQuarter {
        let chapter = Chapter()
        chapter.number = 2
        chapter.arabicTitle = "البقرة"
        chapter.englishTitle = "Al-Baqarah"
        
        let verse = Verse()
        verse.verseID = 8
        verse.number = 8
        verse.text = "وَمِنَ النَّاسِ مَن يَقُولُ آمَنَّا بِاللَّهِ"
        verse.chapter = chapter
        
        let page = Page()
        page.number = 3
        verse.page1441 = page
        
        return ChaptersByQuarter(
            id: 2,
            quarterNumber: 2,
            hizbNumber: 1,
            hizbFraction: 2,
            arabicTitle: "الربع الثاني",
            englishTitle: "Second Quarter",
            chapters: [chapter],
            firstPage: 3,
            firstVerse: verse
        )
    }
    
    /// Prebuilt test fixture representing the third quarter of Hizb 1.
    public static var mockThirdQuarter: ChaptersByQuarter {
        let chapter = Chapter()
        chapter.number = 2
        chapter.arabicTitle = "البقرة"
        chapter.englishTitle = "Al-Baqarah"
        
        let verse = Verse()
        verse.verseID = 26
        verse.number = 26
        verse.text = "إِنَّ اللَّهَ لَا يَسْتَحْيِي أَن يَضْرِبَ مَثَلًا"
        verse.chapter = chapter
        
        let page = Page()
        page.number = 5
        verse.page1441 = page
        
        return ChaptersByQuarter(
            id: 3,
            quarterNumber: 3,
            hizbNumber: 1,
            hizbFraction: 3,
            arabicTitle: "الربع الثالث",
            englishTitle: "Third Quarter",
            chapters: [chapter],
            firstPage: 5,
            firstVerse: verse
        )
    }
    
    /// Prebuilt test fixture representing the fourth quarter of Hizb 1.
    public static var mockFourthQuarter: ChaptersByQuarter {
        let chapter = Chapter()
        chapter.number = 2
        chapter.arabicTitle = "البقرة"
        chapter.englishTitle = "Al-Baqarah"
        
        let verse = Verse()
        verse.verseID = 43
        verse.number = 43
        verse.text = "وَأَقِيمُوا الصَّلَاةَ وَآتُوا الزَّكَاةَ"
        verse.chapter = chapter
        
        let page = Page()
        page.number = 7
        verse.page1441 = page
        
        return ChaptersByQuarter(
            id: 4,
            quarterNumber: 4,
            hizbNumber: 1,
            hizbFraction: 0,
            arabicTitle: "الربع الرابع",
            englishTitle: "Fourth Quarter",
            chapters: [chapter],
            firstPage: 7,
            firstVerse: verse
        )
    }
}

public extension ChaptersByHizb {
    /// Prebuilt test fixture representing Hizb 1 with all four quarters.
    static var mockHizb1: ChaptersByHizb {
        ChaptersByHizb(
            id: 1,
            hizbNumber: 1,
            quarters: [
                .mockFirstQuarter,
                .mockSecondQuarter,
                .mockThirdQuarter,
                .mockFourthQuarter
            ]
        )
    }
}

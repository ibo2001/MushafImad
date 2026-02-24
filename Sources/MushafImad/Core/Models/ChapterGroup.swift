//
//  ChapterGroup.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 31/10/2025.
//

import Foundation

public struct ChaptersByPart: Identifiable {
    public let id: Int
    public let partNumber: Int
    public let arabicTitle: String
    public let englishTitle: String
    public let chapters: [Chapter]
    public let firstPage: Int?
    public let firstVerse: Verse?
}

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
}

public struct ChaptersByHizb: Identifiable {
    public let id: Int
    public let hizbNumber: Int
    public let quarters: [ChaptersByQuarter]
    
    public var hizbTitle: String {
        hizbNumber.quarterTitle
    }
}

public struct ChaptersByType: Identifiable {
    public let id: String
    public let type: String
    public let arabicType: String
    public let chapters: [Chapter]
    public let firstPage: Int?
    public let firstVerse: Verse?
    
    public var isMeccan: Bool {
        id == "meccan"
    }
}


// MARK: - Mock Data Extensions

extension ChaptersByQuarter {
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

//
//  Verse.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

import Foundation
import RealmSwift

public final class Verse: Object, Identifiable {
    @Persisted public var verseID: Int = 0
    @Persisted public var humanReadableID: String = ""  // e.g. "2_255"
    @Persisted public var number: Int = 0
    @Persisted public var text: String = ""
    @Persisted public var textWithoutTashkil: String = ""
    @Persisted public var uthmanicHafsText: String = ""
    @Persisted public var hafsSmartText: String = ""
    @Persisted public var searchableText: String = ""
    @Persisted public var chapter: Chapter?
    @Persisted var part: Part?
    @Persisted var quarter: Quarter?
    @Persisted var section: QuranSection?
    @Persisted public var page1441: Page?
    @Persisted var page1405: Page?
    @Persisted var marker1441: VerseMarker?
    @Persisted var marker1405: VerseMarker?
    @Persisted var highlights1441 = List<VerseHighlight>()
    @Persisted var highlights1405 = List<VerseHighlight>()
    
    public var id: Int { verseID }
    
    @objc nonisolated override public class func primaryKey() -> String? {
        return "verseID"
    }
    
    @objc nonisolated override public class func indexedProperties() -> [String] {
        return ["humanReadableID", "number", "searchableText"]
    }
    
    // Compatibility helpers
    public var chapterNumber: Int {
        return chapter?.number ?? 0
    }
}

extension Verse {
    @MainActor
    public static var mock: Verse {
        let v = Verse()
        v.chapter = Chapter.mock
        v.number = 1
        v.text = "بِسمِ اللَّهِ الرَّحمنِ الرَّحيمِ"
        return v
    }
}

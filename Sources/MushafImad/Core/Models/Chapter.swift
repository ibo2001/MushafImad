//
//  Chapter.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

import Foundation
import RealmSwift

public final class Chapter: Object, Identifiable {
    @Persisted public var identifier: Int = 0
    @Persisted public var number: Int = 0
    @Persisted public var isMeccan: Bool = false
    @Persisted public var title: String = ""
    @Persisted public var arabicTitle: String = ""
    @Persisted public var englishTitle: String = ""
    @Persisted public var titleCodePoint: String = ""
    @Persisted public var searchableText: String = ""
    @Persisted public var searchableKeywords: String = ""
    @Persisted public var verses = List<Verse>()
    @Persisted var header1441: ChapterHeader?
    @Persisted var header1405: ChapterHeader?
    
    // Identifiable conformance
    public var id: Int { identifier }
    
    @objc nonisolated override public class func primaryKey() -> String? {
        return "identifier"
    }
    
    @objc nonisolated override public class func indexedProperties() -> [String] {
        return ["number", "searchableText"]
    }
    
    // Computed properties for compatibility with existing code
    public var startPage: Int {
        // Get first verse's page number
        guard let firstVerse = verses.first,
              let page1441 = firstVerse.page1441 else { return 604 }
        return page1441.number
    }
    
    public var endPage: Int {
        // Get last verse's page number
        guard let lastVerse = verses.last,
              let page1441 = lastVerse.page1441 else { return 1 }
        return page1441.number
    }
    
    public var versesCount: Int {
        return verses.count > 0 ? verses.count : 286
    }
    
    public var pagesCount: Int {
        guard startPage > 0 && endPage > 0 else { return 0 }
        return endPage - startPage + 1
    }
    
    public var displayTitle: String {
        let preferredLanguage: String
        if #available(macOS 13.0, iOS 16.0, *) {
            preferredLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            preferredLanguage = Locale.current.languageCode ?? "en"
        }
        return preferredLanguage == "ar" ? arabicTitle : englishTitle
    }
}


extension Chapter {
    @MainActor
    public static var mock: Chapter {
        if let c = RealmService.shared.getChapter(number: 1) {
            return c
        }
        let fatiha = Chapter()

        fatiha.number = 1
        fatiha.arabicTitle = "الفاتحة"
        fatiha.englishTitle = "Al-Fatihah"
        fatiha.verses = List<Verse>()
        return fatiha
    }
}

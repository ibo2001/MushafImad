//
//  Page.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

import Foundation
import RealmSwift

public final class Page: Object {
    @Persisted public var identifier: Int = 0
    @Persisted public var number: Int = 0
    @Persisted public var isRight: Bool = false
    @Persisted public var header1441: PageHeader?
    @Persisted public var header1405: PageHeader?
    @Persisted public var chapterHeaders1441 = List<ChapterHeader>()
    @Persisted public var chapterHeaders1405 = List<ChapterHeader>()
    @Persisted public var verses1441 = List<Verse>()
    @Persisted public var verses1405 = List<Verse>()
    
    @objc nonisolated override public class func primaryKey() -> String? {
        return "identifier"
    }

    @objc nonisolated override public class func indexedProperties() -> [String] {
        return ["number"]
    }

    /// Returns the verses list for the given Mushaf layout.
    public func verses(for mushafType: MushafType) -> [Verse] {
        switch mushafType {
        case .hafs1441: return Array(verses1441)
        case .hafs1405: return Array(verses1405)
        }
    }

    /// Returns chapter headers for the given Mushaf layout.
    public func chapterHeaders(for mushafType: MushafType) -> [ChapterHeader] {
        switch mushafType {
        case .hafs1441: return Array(chapterHeaders1441)
        case .hafs1405: return Array(chapterHeaders1405)
        }
    }

    /// Returns the page header for the given Mushaf layout.
    public func header(for mushafType: MushafType) -> PageHeader? {
        switch mushafType {
        case .hafs1441: return header1441
        case .hafs1405: return header1405
        }
    }

    /// Whether this page has image-rendering data for the given layout.
    public func hasImageData(for mushafType: MushafType) -> Bool {
        let v = verses(for: mushafType)
        guard !v.isEmpty else { return false }
        // Check if at least some verses have markers (line-level data)
        return v.contains { $0.marker(for: mushafType) != nil }
    }
}

extension Page {
    @MainActor
    public static var mock: Page {
        let page = Page()
        page.identifier = 1
        page.number = 42
        return page
    }
}

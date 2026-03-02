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

//
//  Part.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

import Foundation
import RealmSwift

public final class Part: Object {
    @Persisted public var identifier: Int = 0
    @Persisted public var number: Int = 0
    @Persisted public var arabicTitle: String = ""
    @Persisted public var englishTitle: String = ""
    @Persisted public var chapters = List<Chapter>()
    @Persisted public var quarters = List<Quarter>()
    @Persisted public var verses = List<Verse>()
    
    @objc nonisolated override public class func primaryKey() -> String? {
        return "identifier"
    }
    
    @objc nonisolated override public class func indexedProperties() -> [String] {
        return ["number"]
    }
}

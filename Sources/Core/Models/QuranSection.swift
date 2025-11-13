//
//  Section.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

import Foundation
import RealmSwift

public final class QuranSection: Object {
    @Persisted public var identifier: Int = 0
    @Persisted public var verses = List<Verse>()
    
    @objc nonisolated override public class func primaryKey() -> String? {
        return "identifier"
    }
}

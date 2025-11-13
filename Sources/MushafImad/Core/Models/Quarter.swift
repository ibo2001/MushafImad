//
//  Quarter.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

import Foundation
import RealmSwift

public final class Quarter: Object {
    @Persisted public var identifier: Int = 0
    @Persisted public var hizbNumber: Int = 0
    @Persisted public var hizbFraction: Int = 0  // 0=start, 1=quarter, 2=half, 3=three-quarters
    @Persisted public var arabicTitle: String = ""
    @Persisted public var englishTitle: String = ""
    @Persisted public var part: Part?
    @Persisted public var verses = List<Verse>()
    
    @objc nonisolated override public class func primaryKey() -> String? {
        return "identifier"
    }
    
    @objc nonisolated override public class func indexedProperties() -> [String] {
        return ["hizbNumber"]
    }
    
    // Helper computed property for UI
    public var hizbQuarterProgress: HizbQuarterProgress? {
        switch hizbFraction {
        case 1: return .quarter
        case 2: return .half
        case 3: return .threeQuarters
        default: return nil
        }
    }
}

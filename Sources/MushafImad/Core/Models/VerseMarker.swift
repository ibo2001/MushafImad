//
//  VerseMarker.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

import Foundation
import RealmSwift

public final class VerseMarker: Object {
    @Persisted public var numberCodePoint: String = ""
    @Persisted public var line: Int = 0
    @Persisted public var centerX: Float = 0
    @Persisted public var centerY: Float = 0
}

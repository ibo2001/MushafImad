//
//  VerseHighlight.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

import Foundation
import RealmSwift

public final class VerseHighlight: Object {
    @Persisted public var line: Int = 0
    @Persisted public var left: Float = 0
    @Persisted public var right: Float = 0
}

//
//  ChapterHeader.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

import Foundation
import RealmSwift

public final class ChapterHeader: Object {
    @Persisted public var chapter: Chapter?
    @Persisted public var page: Page?
    @Persisted public var line: Int = 0
    @Persisted public var centerX: Float = 0
    @Persisted public var centerY: Float = 0
}

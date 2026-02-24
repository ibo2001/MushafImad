//
//  PageHeader.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

import Foundation
import RealmSwift

public final class PageHeader: Object {
    @Persisted public var part: Part?
    @Persisted public var quarter: Quarter?
    @Persisted public var chapters = List<Chapter>()
}

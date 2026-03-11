//
//  GazePoint.swift
//  MushafImad
//
//  Created by Tamer on 11/03/2026.
//

import Foundation

public struct GazePoint: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let timestamp: Date
    public let confidence: Double

    public init(
        x: Double,
        y: Double,
        timestamp: Date = .now,
        confidence: Double = 1.0
    ) {
        self.x = x
        self.y = y
        self.timestamp = timestamp
        self.confidence = confidence
    }

    public var line: Int {
        let clamped = min(max(y, 0), 1)
        return min(Int(clamped * 15), 14)
    }
}

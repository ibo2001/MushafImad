//
//  HizbDisplayInfo.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 31/10/2025.
//

import Foundation

public struct HizbDisplayInfo {
    public let number: Int
    public let fraction: Double

    public init(number: Int, hizbFraction: Int) {
        self.number = number
        self.fraction = HizbDisplayInfo.fractionValue(for: hizbFraction)
    }

    public var formattedFraction: String {
        String(format: "%.2f", fraction)
    }

    private static func fractionValue(for hizbFraction: Int) -> Double {
        switch hizbFraction {
        case 1:
            return 0.25
        case 2:
            return 0.5
        case 3:
            return 0.75
        default:
            return 1.0
        }
    }
}


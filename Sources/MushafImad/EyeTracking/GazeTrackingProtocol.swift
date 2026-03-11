//
//  GazeTrackingProtocol.swift
//  MushafImad
//
//  Created by Tamer on 11/03/2026.
//

import Foundation

@MainActor
public protocol GazeTrackingProvider: AnyObject, Sendable {
    var isAvailable: Bool { get }
    var latestGazePoint: GazePoint? { get }
    func startTracking()
    func stopTracking()
    func updatePage(_ page: Int)
    func updateReadingSpeed(_ secondsPerLine: Double)
}

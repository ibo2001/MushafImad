//
//  ScrollBasedGazeProvider.swift
//  MushafImad
//
//  Created by Tamer on 11/03/2026.
//

import Foundation
import Combine

@MainActor
public final class ScrollBasedGazeProvider: GazeTrackingProvider, ObservableObject {
    public var isAvailable: Bool { true }
    @Published public private(set) var latestGazePoint: GazePoint?

    private var isTracking = false
    private var currentPage: Int = 1
    private var pageArrivalTime: Date = .now
    private var timer: Timer?

    private let linesPerPage = 15
    private let wordsPerLine: Double = 8
    private let baseSecondsPerLine: Double = 4.0
    private var readingSpeedMultiplier: Double = 1.0

    private var effectiveSecondsPerLine: Double {
        baseSecondsPerLine * readingSpeedMultiplier
    }

    public init() {}

    deinit {
        timer?.invalidate()
        timer = nil
    }

    public func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        pageArrivalTime = .now
        updateGazeEstimate()
        startTimer()
    }

    public func stopTracking() {
        isTracking = false
        timer?.invalidate()
        timer = nil
        latestGazePoint = nil
    }

    public func updatePage(_ page: Int) {
        guard page != currentPage else { return }
        currentPage = page
        pageArrivalTime = .now
    }

    public func updateReadingSpeed(_ secondsPerLine: Double) {
        guard secondsPerLine > 0 else { return }
        readingSpeedMultiplier = secondsPerLine / baseSecondsPerLine
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateGazeEstimate()
            }
        }
    }

    private func updateGazeEstimate() {
        guard isTracking else { return }

        let elapsed = Date.now.timeIntervalSince(pageArrivalTime)
        let estimatedLine = min(
            Int(elapsed / effectiveSecondsPerLine),
            linesPerPage - 1
        )

        let progressInLine = (elapsed - Double(estimatedLine) * effectiveSecondsPerLine)
            / effectiveSecondsPerLine
        let clampedProgress = min(max(progressInLine, 0), 1)

        // Arabic reads right-to-left: x goes from 1.0 (right) to 0.0 (left)
        let x = 1.0 - clampedProgress
        let y = (Double(estimatedLine) + 0.5) / Double(linesPerPage)

        latestGazePoint = GazePoint(
            x: x,
            y: y,
            confidence: 0.6
        )
    }
}

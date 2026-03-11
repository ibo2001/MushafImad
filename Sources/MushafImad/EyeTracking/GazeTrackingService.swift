//
//  GazeTrackingService.swift
//  MushafImad
//
//  Created by Tamer on 11/03/2026.
//

import SwiftUI
import SwiftData
import Combine

@MainActor
public final class GazeTrackingService: ObservableObject {
    @AppStorage("gaze_tracking_enabled") public var isEnabled: Bool = false {
        didSet { updateTrackingState() }
    }
    @AppStorage("gaze_auto_save") public var autoSaveProgress: Bool = true
    @AppStorage("gaze_auto_advance") public var autoAdvancePage: Bool = false
    @AppStorage("gaze_reading_speed") public var readingSpeed: Double = 4.0

    @Published public private(set) var currentVerse: GazeToVerseResolver.ResolvedVerse?
    @Published public private(set) var shouldAdvancePage = false

    private let gazeProvider = ScrollBasedGazeProvider()
    private let progressTracker = ReadingProgressTracker()
    private var cancellables = Set<AnyCancellable>()
    private var isActive = false
    private var currentPage: Int = 1
    private var mushafType: MushafType = .hafs1441
    private var dwellOnLastLineStart: Date?
    private let autoAdvanceDwell: TimeInterval = 3.0

    public init() {
        gazeProvider.$latestGazePoint
            .compactMap { $0 }
            .sink { [weak self] point in
                self?.handleGazeUpdate(point)
            }
            .store(in: &cancellables)

        progressTracker.$currentVerse
            .assign(to: &$currentVerse)
    }

    public func activate() {
        isActive = true
        updateTrackingState()
    }

    public func deactivate() {
        isActive = false
        gazeProvider.stopTracking()
        progressTracker.reset()
        shouldAdvancePage = false
        dwellOnLastLineStart = nil
    }

    public func updatePage(_ page: Int, mushafType: MushafType = .hafs1441) {
        currentPage = page
        self.mushafType = mushafType
        gazeProvider.updatePage(page)
        shouldAdvancePage = false
        dwellOnLastLineStart = nil
    }

    public func saveProgress(modelContext: ModelContext) {
        guard isEnabled, autoSaveProgress else { return }
        progressTracker.saveProgressIfNeeded(modelContext: modelContext)
        progressTracker.updateKhatmaProgress(
            page: currentPage,
            modelContext: modelContext
        )
    }

    public func didAdvancePage() {
        shouldAdvancePage = false
        dwellOnLastLineStart = nil
    }

    private func updateTrackingState() {
        if isEnabled, isActive {
            gazeProvider.startTracking()
        } else {
            gazeProvider.stopTracking()
            progressTracker.reset()
            shouldAdvancePage = false
        }
    }

    private func handleGazeUpdate(_ point: GazePoint) {
        progressTracker.update(
            gazePoint: point,
            page: currentPage,
            mushafType: mushafType
        )

        guard autoAdvancePage else {
            dwellOnLastLineStart = nil
            return
        }

        if progressTracker.isOnLastLine {
            if dwellOnLastLineStart == nil {
                dwellOnLastLineStart = .now
            }
            if let start = dwellOnLastLineStart,
               Date.now.timeIntervalSince(start) >= autoAdvanceDwell {
                shouldAdvancePage = true
            }
        } else {
            dwellOnLastLineStart = nil
            shouldAdvancePage = false
        }
    }
}

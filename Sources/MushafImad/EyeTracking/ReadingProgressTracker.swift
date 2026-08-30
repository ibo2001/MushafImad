//
//  ReadingProgressTracker.swift
//  MushafImad
//
//  Orchestrates eye-tracking data into meaningful reading progress:
//  - Dwell time detection per verse
//  - Auto-highlight of the active verse
//  - Auto-advance to next page
//  - Persistence of reading sessions
//
//  Created for Ramadan Impact — exploratory research (Issue #22).
//

import Foundation
import SwiftUI
import Combine
import SwiftData

/// Orchestrates gaze data from `EyeTrackingService` or `FallbackGazeEstimator`
/// into actionable reading progress events.
///
/// ## Responsibilities
/// 1. Consume gaze points and map them to verses via `GazeToVerseMapper`
/// 2. Detect when the user has "read" a verse (dwell time exceeded)
/// 3. Track the currently active verse for auto-highlighting
/// 4. Detect page completion and trigger auto-advance
/// 5. Persist reading sessions via SwiftData
@MainActor
public final class ReadingProgressTracker: ObservableObject {
    
    // MARK: - Published State
    
    /// The verse the user is currently reading (based on dwell detection).
    @Published public private(set) var activeVerse: Verse?
    
    /// The line the gaze is currently on (0–14).
    @Published public private(set) var activeLineIndex: Int = 0
    
    /// Whether the user appears to have finished reading the current page.
    @Published public private(set) var pageCompleted: Bool = false
    
    /// Reading progress as a fraction (0.0 – 1.0) based on the active line.
    @Published public private(set) var readingProgress: Double = 0
    
    /// Whether the tracker is actively monitoring.
    @Published public private(set) var isTracking: Bool = false
    
    /// Last reading session result (for persistence).
    @Published public private(set) var currentSession: ReadingSession?
    
    /// Sessions finalized during page transitions but not yet written to SwiftData.
    /// Accumulating into a buffer prevents a session from being overwritten when
    /// ``startTracking`` calls ``stopTracking`` before ``persistSession(context:)`` runs.
    private var pendingSessions: [ReadingSession] = []
    
    // MARK: - Configuration
    
    /// Minimum dwell time in seconds before a verse is considered "being read".
    /// Valid range: > 0
    public var dwellTimeThreshold: TimeInterval = 1.5 {
        didSet {
            guard dwellTimeThreshold > 0 else {
                dwellTimeThreshold = oldValue
                assertionFailure("dwellTimeThreshold must be greater than 0")
                return
            }
        }
    }
    
    /// Time in seconds the user must dwell on the last line to trigger auto-advance.
    /// Valid range: > 0
    public var pageCompletionDwellTime: TimeInterval = 3.0 {
        didSet {
            guard pageCompletionDwellTime > 0 else {
                pageCompletionDwellTime = oldValue
                assertionFailure("pageCompletionDwellTime must be greater than 0")
                return
            }
        }
    }
    
    /// Whether to automatically advance to the next page when page is completed.
    public var autoAdvanceEnabled: Bool = true
    
    /// Callback invoked when the tracker determines the user has finished the page.
    public var onPageCompleted: (() -> Void)?
    
    /// Callback invoked when the active verse changes (for highlighting).
    public var onActiveVerseChanged: ((Verse?) -> Void)?
    
    // MARK: - Dependencies
    
    private let gazeMapper = GazeToVerseMapper()
    
    // MARK: - Private State
    
    /// Tracking method used for current session
    public var trackingMethod: TrackingMethod = .eyeTracking
    
    /// Currently tracked verse and the time the gaze first landed on it.
    private var currentDwellVerse: Verse?
    private var dwellStartTime: Date?
    
    /// The verse most recently mapped from a gaze point (even if dwell threshold not met).
    private var lastMappedVerse: Verse?
    
    /// For page completion detection
    private var lastLineDwellStart: Date?
    
    /// Running session data
    private var sessionStartTime: Date?
    private var sessionVerseID: Int?
    private var confidenceAccumulator: Float = 0
    private var confidenceSampleCount: Int = 0
    
    /// Pause tracking: total wall-clock time spent in paused state during this session.
    private var accumulatedPausedDuration: TimeInterval = 0
    /// When the current pause started (nil if not currently paused).
    private var pauseStartTime: Date?
    
    /// Current page context
    private var currentPageNumber: Int = 0
    private var currentPageVerses: [Verse] = []

    /// How far the page's content has scrolled past its top edge. Only
    /// meaningful in landscape, where lines render inside a scroll view
    /// taller than the viewport; the caller must keep this current or gaze
    /// points below the first screenful of lines will fail to map.
    private var currentScrollOffset: CGFloat = 0
    
    /// Cancellable subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    public init() {}
    
    // MARK: - Public API
    
    /// Begin tracking reading progress for a specific page.
    ///
    /// - Parameters:
    ///   - pageNumber: The Mushaf page number (1–604).
    ///   - verses: The verses on this page.
    ///   - pageFrame: The on-screen frame of the page content area.
    ///   - headerOffset: The height of the page header above the lines.
    public func startTracking(
        pageNumber: Int,
        verses: [Verse],
        pageFrame: CGRect,
        headerOffset: CGFloat = 40
    ) {
        stopTracking()

        currentPageNumber = pageNumber
        currentPageVerses = verses
        pageCompleted = false
        readingProgress = 0
        activeVerse = nil
        activeLineIndex = 0
        currentScrollOffset = 0

        gazeMapper.updatePageGeometry(
            frame: pageFrame,
            headerOffset: headerOffset,
            isLandscape: pageFrame.width > pageFrame.height
        )

        // Initialize session
        sessionStartTime = Date()
        sessionVerseID = nil
        confidenceAccumulator = 0
        confidenceSampleCount = 0
        lastMappedVerse = nil
        accumulatedPausedDuration = 0
        pauseStartTime = nil

        isTracking = true

        AppLogger.shared.info("Reading progress tracker started for page \(pageNumber)", category: .ui)
    }
    
    /// Stop tracking and persist the session.
    public func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        
        // Create final session for persistence and add to pending queue
        if let session = finalizeSession() {
            pendingSessions.append(session)
        }
        
        // If we were paused, close out the current pause interval
        if let pauseStart = pauseStartTime {
            accumulatedPausedDuration += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        
        // Reset state
        currentDwellVerse = nil
        dwellStartTime = nil
        lastLineDwellStart = nil
        currentPageVerses = []
        
        AppLogger.shared.info("Reading progress tracker stopped", category: .ui)
    }
    
    /// Process a new gaze point from either the eye tracking service
    /// or the fallback estimator.
    ///
    /// This is the main entry point — call it each time a new gaze sample arrives.
    ///
    /// - Parameter gazePoint: The latest gaze estimate.
    public func processGazePoint(_ gazePoint: GazePoint) {
        guard isTracking else { return }
        
        // Map gaze to a verse
        guard let result = gazeMapper.mapGazeToVerse(
            gazePoint: gazePoint,
            verses: currentPageVerses,
            scrollOffset: currentScrollOffset
        ) else {
            // Gaze is outside the page content area — clear stale dwell state so an
            // out-of-bounds sample cannot silently extend or complete a dwell on the
            // next valid sample.
            currentDwellVerse = nil
            dwellStartTime = nil
            lastLineDwellStart = nil
            return
        }
        
        // Update active line
        activeLineIndex = result.lineIndex
        readingProgress = Double(result.lineIndex) / Double(GazeToVerseMapper.linesPerPage - 1)
        
        // Accumulate confidence
        confidenceAccumulator += gazePoint.confidence
        confidenceSampleCount += 1
        
        // Dwell detection
        processDwellDetection(result: result)
        
        // Update last mapped verse immediately (even if dwell not confirmed)
        if let verseID = result.verseID {
            lastMappedVerse = currentPageVerses.first(where: { $0.verseID == verseID })
        }
        
        // Page completion detection
        processPageCompletion(lineIndex: result.lineIndex)
    }
    
    /// Update the page geometry (e.g., after rotation).
    ///
    /// - Parameters:
    ///   - frame: The on-screen frame of the page content area.
    ///   - headerOffset: The height of the page header above the lines.
    public func updateGeometry(frame: CGRect, headerOffset: CGFloat = 40) {
        gazeMapper.updatePageGeometry(
            frame: frame,
            headerOffset: headerOffset,
            isLandscape: frame.width > frame.height
        )
    }

    /// Update how far the page's content has scrolled past its top edge.
    ///
    /// Only meaningful in landscape, where lines render inside a scroll view
    /// taller than the viewport. Call this whenever the scroll position
    /// changes so subsequent gaze points map to the correct line.
    public func updateScrollOffset(_ offset: CGFloat) {
        currentScrollOffset = offset
    }
    
    // MARK: - Dwell Detection
    
    private func processDwellDetection(result: MappedGazeResult) {
        let verse = currentPageVerses.first(where: { $0.verseID == result.verseID })
        
        guard let verse = verse else {
            // Gaze is on a line but not on any verse — reset dwell timer
            currentDwellVerse = nil
            dwellStartTime = nil
            return
        }
        
        if currentDwellVerse?.verseID == verse.verseID {
            // Still dwelling on the same verse — check if threshold met
            if let start = dwellStartTime,
               Date().timeIntervalSince(start) >= dwellTimeThreshold {
                // Verse is considered "being read"
                if activeVerse?.verseID != verse.verseID {
                    activeVerse = verse
                    sessionVerseID = verse.verseID
                    onActiveVerseChanged?(verse)
                    
                    AppLogger.shared.trace(
                        "Active verse: \(verse.chapterNumber):\(verse.number) (dwell: \(String(format: "%.1f", Date().timeIntervalSince(start)))s)",
                        category: .ui
                    )
                }
            }
        } else {
            // Gaze moved to a different verse — reset dwell timer
            currentDwellVerse = verse
            dwellStartTime = Date()
        }
    }
    
    // MARK: - Page Completion
    
    private func processPageCompletion(lineIndex: Int) {
        guard !pageCompleted else { return }
        
        let isLastLine = lineIndex >= GazeToVerseMapper.linesPerPage - 2  // last 2 lines
        
        if isLastLine {
            if lastLineDwellStart == nil {
                lastLineDwellStart = Date()
            } else if let start = lastLineDwellStart,
                      Date().timeIntervalSince(start) >= pageCompletionDwellTime {
                // User has been reading the last lines long enough
                pageCompleted = true
                readingProgress = 1.0
                
                AppLogger.shared.info("Page \(currentPageNumber) completed via eye tracking", category: .ui)
                
                if autoAdvanceEnabled {
                    onPageCompleted?()
                }
            }
        } else {
            // Not on last line — reset
            lastLineDwellStart = nil
        }
    }
    
    // MARK: - Session Persistence
    
    @discardableResult
    private func finalizeSession() -> ReadingSession? {
        guard let startTime = sessionStartTime else { return nil }
        
        let verse = activeVerse ?? lastMappedVerse
        let avgConfidence: Float
        if confidenceSampleCount > 0 {
            avgConfidence = confidenceAccumulator / Float(confidenceSampleCount)
        } else {
            avgConfidence = 0
        }
        
        // Compute active (non-paused) duration. If we are currently paused, include
        // the ongoing pause interval in the total paused time so it is excluded.
        let now = Date()
        let totalPaused = accumulatedPausedDuration + (pauseStartTime.map { now.timeIntervalSince($0) } ?? 0)
        let activeDuration = max(0, now.timeIntervalSince(startTime) - totalPaused)
        
        let session = ReadingSession(
            pageNumber: currentPageNumber,
            lastVerseID: verse?.verseID ?? 0,
            chapterNumber: verse?.chapterNumber ?? 0,
            verseNumber: verse?.number ?? 0,
            lastLineIndex: activeLineIndex,
            startedAt: startTime,
            lastUpdatedAt: now,
            activeReadingDuration: activeDuration,
            trackingMethod: trackingMethod,
            completedPage: pageCompleted,
            averageConfidence: avgConfidence
        )
        
        currentSession = session
        
        AppLogger.shared.info(
            "Reading session finalized — page \(currentPageNumber), verse \(verse?.chapterNumber ?? 0):\(verse?.number ?? 0), active duration \(String(format: "%.1f", activeDuration))s (paused \(String(format: "%.1f", totalPaused))s)",
            category: .ui
        )
        
        return session
    }
    
    // MARK: - Pause / Resume
    
    /// Record the start of a pause interval. Call when tracking is interrupted
    /// (e.g. app backgrounded, settings sheet presented, face lost).
    public func pauseTracking() {
        guard isTracking, pauseStartTime == nil else { return }
        pauseStartTime = Date()
        AppLogger.shared.debug("Reading progress tracker paused", category: .ui)
    }
    
    /// Close the current pause interval and resume accumulating active time.
    public func resumeTracking() {
        guard isTracking, let pauseStart = pauseStartTime else { return }
        accumulatedPausedDuration += Date().timeIntervalSince(pauseStart)
        pauseStartTime = nil
        AppLogger.shared.debug("Reading progress tracker resumed (total paused so far: \(String(format: "%.1f", accumulatedPausedDuration))s)", category: .ui)
    }
    
    /// Persist the current session to SwiftData.
    ///
    /// - Parameter context: The SwiftData model context to save into.
    public func persistSession(context: ModelContext) {
        guard !pendingSessions.isEmpty else {
            AppLogger.shared.debug("No pending reading sessions to persist", category: .ui)
            return
        }
        
        for session in pendingSessions {
            context.insert(session)
        }
        
        do {
            try context.save()
            AppLogger.shared.info("Persisted \(pendingSessions.count) reading session(s) to SwiftData", category: .ui)
            pendingSessions.removeAll()
        } catch {
            AppLogger.shared.error("Failed to persist reading sessions: \(error.localizedDescription)", category: .ui)
        }
    }
    
    /// Retrieve the most recent reading session for a specific page.
    ///
    /// - Parameters:
    ///   - pageNumber: The page to look up.
    ///   - context: SwiftData model context.
    /// - Returns: The most recent `ReadingSession` for that page, if any.
    public func lastSession(
        forPage pageNumber: Int,
        context: ModelContext
    ) -> ReadingSession? {
        let descriptor = FetchDescriptor<ReadingSession>(
            predicate: #Predicate { $0.pageNumber == pageNumber },
            sortBy: [SortDescriptor(\.lastUpdatedAt, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }
    
    /// Retrieve the user's most recent reading position across all pages.
    ///
    /// - Parameter context: SwiftData model context.
    /// - Returns: The most recent `ReadingSession` overall, if any.
    public func lastReadingPosition(context: ModelContext) -> ReadingSession? {
        let descriptor = FetchDescriptor<ReadingSession>(
            sortBy: [SortDescriptor(\.lastUpdatedAt, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }
}

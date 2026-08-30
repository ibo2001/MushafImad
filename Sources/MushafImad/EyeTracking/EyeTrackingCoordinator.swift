//
//  EyeTrackingCoordinator.swift
//  MushafImad
//
//  Ties together the EyeTrackingService, FallbackGazeEstimator,
//  GazeToVerseMapper, and ReadingProgressTracker into a single
//  coordinator that MushafView can consume.
//
//  Created for Ramadan Impact — exploratory research (Issue #22).
//

import Foundation
import SwiftUI
import Combine
import SwiftData

/// Coordinates all eye-tracking subsystems and provides a single
/// integration point for `MushafView`.
///
/// Usage:
/// ```swift
/// @StateObject private var eyeCoordinator = EyeTrackingCoordinator()
/// // In your view body:
/// .onAppear { eyeCoordinator.activate(pageNumber: 1, verses: [...], pageFrame: ...) }
/// .onDisappear { eyeCoordinator.deactivate(context: modelContext) }
/// ```
@MainActor
public final class EyeTrackingCoordinator: ObservableObject {
    
    // MARK: - Sub-services (internal for implementation)
    
    internal let eyeTrackingService = EyeTrackingService()
    internal let fallbackEstimator = FallbackGazeEstimator()
    internal let progressTracker = ReadingProgressTracker()
    
    // MARK: - Published State
    
    /// The verse currently being read (auto-highlighted).
    @Published public var gazeHighlightedVerse: Verse?
    
    /// Current gaze point for overlay rendering.
    @Published public var currentGaze: GazePoint?
    
    /// Overall tracking state.
    @Published public var trackingState: EyeTrackingState = .inactive
    
    /// Whether the feature is enabled by the user.
    @AppStorage("mushaf_imad_eye_tracking_enabled") public var isEnabled: Bool = false
    @AppStorage("mushaf_imad_eye_tracking_auto_highlight") private var autoHighlight: Bool = true
    
    /// Enable or disable eye-tracking.
    ///
    /// Passing `context` when disabling ensures any buffered sessions are
    /// flushed to SwiftData before the coordinator clears its state.
    ///
    /// When enabling, this method **only** sets `isEnabled = true`.
    /// The actual service start (including gaze-binding setup and
    /// `progressTracker` configuration) is deferred to the next call to
    /// `activate(pageNumber:verses:pageFrame:onPageCompleted:)`, which
    /// guarantees that all subsystems are ready before gaze samples arrive.
    public func setEnabled(_ enabled: Bool, context: ModelContext? = nil) {
        isEnabled = enabled
        if !enabled {
            deactivate(context: context)
        }
    }
    @AppStorage("mushaf_imad_eye_tracking_auto_advance") private var autoAdvance: Bool = false
    @AppStorage("mushaf_imad_eye_tracking_show_overlay") public var showOverlay: Bool = false
    @AppStorage("mushaf_imad_eye_tracking_show_debug") public var showDebugInfo: Bool = false
    @AppStorage("mushaf_imad_eye_tracking_dwell_time") private var dwellTime: Double = 1.5
    @AppStorage("mushaf_imad_eye_tracking_reading_speed") private var readingSpeed: Double = 80
    @AppStorage("mushaf_imad_eye_tracking_use_fallback") private var useFallbackMode: Bool = false
    
    // MARK: - Private
    
    private var cancellables = Set<AnyCancellable>()
    private var gazeCancellables = Set<AnyCancellable>()
    private var gazeUpdateTimer: Timer?
    
    // MARK: - Init
    
    public init() {
        setupBindings()
    }
    
    // MARK: - Bindings
    
    private func setupBindings() {
        // Forward active verse changes
        progressTracker.onActiveVerseChanged = { [weak self] verse in
            guard let self else { return }
            if self.autoHighlight {
                self.gazeHighlightedVerse = verse
            } else {
                DispatchQueue.main.async {
                    self.gazeHighlightedVerse = nil
                }
            }
        }
        
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if !self.autoHighlight && self.gazeHighlightedVerse != nil {
                    self.gazeHighlightedVerse = nil
                }
            }
            .store(in: &cancellables)

        
        // Observe eye tracking service state
        eyeTrackingService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.trackingState = state
            }
            .store(in: &cancellables)
        
    }
    
    private func setupGazeBindings() {
        // Forward gaze from eye tracking service
        eyeTrackingService.$currentGaze
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] gaze in
                guard let self else { return }
                self.currentGaze = gaze
                self.progressTracker.processGazePoint(gaze)
            }
            .store(in: &gazeCancellables)
        
        // Forward gaze from fallback estimator
        fallbackEstimator.$estimatedGaze
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] gaze in
                guard let self else { return }
                // Only use fallback when eye tracking is not active
                guard !self.eyeTrackingService.isSupported || self.useFallbackMode else { return }
                self.currentGaze = gaze
                self.progressTracker.processGazePoint(gaze)
            }
            .store(in: &gazeCancellables)
    }
    
    // MARK: - Lifecycle
    
    /// Activate tracking for a specific page.
    ///
    /// - Parameters:
    ///   - pageNumber: The Mushaf page number (1–604).
    ///   - verses: The verses on the current page.
    ///   - pageFrame: The on-screen frame of the page content area.
    ///   - headerOffset: The height of the page header above the lines.
    ///   - onPageCompleted: Callback when the tracker detects page completion.
    public func activate(
        pageNumber: Int,
        verses: [Verse],
        pageFrame: CGRect,
        headerOffset: CGFloat = 40,
        onPageCompleted: (() -> Void)? = nil
    ) {
        guard isEnabled else { return }
        
        gazeCancellables.removeAll()
        eyeTrackingService.stopTracking()
        fallbackEstimator.stopEstimating()
        setupGazeBindings()
        
        // Configure the progress tracker
        progressTracker.dwellTimeThreshold = dwellTime
        progressTracker.autoAdvanceEnabled = autoAdvance
        progressTracker.onPageCompleted = onPageCompleted
        
        // Start tracking
        // Start the appropriate gaze source
        if eyeTrackingService.isSupported && !useFallbackMode {
            progressTracker.trackingMethod = .eyeTracking
            eyeTrackingService.startTracking()
            progressTracker.startTracking(
                pageNumber: pageNumber,
                verses: verses,
                pageFrame: pageFrame,
                headerOffset: headerOffset
            )
        } else if useFallbackMode {
            // User has explicitly requested heuristic (fallback) mode
            progressTracker.trackingMethod = .heuristic
            fallbackEstimator.arabicWordsPerMinute = readingSpeed
            progressTracker.startTracking(
                pageNumber: pageNumber,
                verses: verses,
                pageFrame: pageFrame,
                headerOffset: headerOffset
            )
            fallbackEstimator.startForPage(pageFrame: pageFrame)
            trackingState = .tracking(GazePoint(screenPosition: .zero, confidence: 0.5))
        } else {
            // TrueDepth unsupported and fallback mode is off — do not start heuristic tracking
            progressTracker.trackingMethod = .eyeTracking
            trackingState = .unavailable(reason: String(localized: "TrueDepth camera is required but not available on this device."))
        }
        
        AppLogger.shared.info("Eye tracking coordinator activated for page \(pageNumber)", category: .ui)
    }
    
    /// Deactivate all tracking.
    public func deactivate(context: ModelContext? = nil) {
        eyeTrackingService.stopTracking()
        fallbackEstimator.stopEstimating()
        progressTracker.stopTracking()
        if let context = context {
            progressTracker.persistSession(context: context)
        }
        gazeHighlightedVerse = nil
        currentGaze = nil
        trackingState = .inactive
    }
    
    /// Update geometry after layout changes.
    public func updateGeometry(frame: CGRect, headerOffset: CGFloat = 40) {
        progressTracker.updateGeometry(frame: frame, headerOffset: headerOffset)
        fallbackEstimator.updateGeometry(frame: frame)
    }

    /// Update how far the page's content has scrolled past its top edge.
    /// Only meaningful in landscape; see `ReadingProgressTracker.updateScrollOffset`.
    public func updateScrollOffset(_ offset: CGFloat) {
        progressTracker.updateScrollOffset(offset)
    }
    
    /// Pause tracking (app backgrounded, sheet presented, etc.).
    public func pause() {
        progressTracker.pauseTracking()
        fallbackEstimator.pause()
        if eyeTrackingService.isSupported && !useFallbackMode {
            eyeTrackingService.stopTracking()
        }
    }
    
    /// Resume tracking after a pause.
    public func resume() {
        progressTracker.resumeTracking()
        fallbackEstimator.resume()
        if eyeTrackingService.isSupported && !useFallbackMode {
            eyeTrackingService.startTracking()
        }
    }
}

//
//  QuranPlayerViewModel.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 02/11/2025.
//

import AVFoundation
import Combine
import Foundation

/// View model powering the audio player UI, coordinating AVPlayer with verse timings.
@MainActor
public final class QuranPlayerViewModel: ObservableObject {
    /// High-level playback progression states emitted to observers.
    public enum PlaybackState: Equatable {
        case idle
        case loading
        case ready
        case playing
        case paused
        case finished
        case failed(String)
    }

    // MARK: - Published State

    @Published public private(set) var playbackState: PlaybackState = .idle
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var playbackRate: Float = 1.0
    @Published public private(set) var isBuffering: Bool = false
    @Published public private(set) var isScrubbing: Bool = false
    @Published public var isRepeatEnabled: Bool = false
    @Published public private(set) var currentVerseNumber: Int? = nil

    // MARK: - Public Configuration

    public var chapterName: String { chapterNameInternal }
    public var reciterName: String { reciterNameInternal }
    public let playbackRates: [Float] = [0.75, 1.0, 1.25, 1.5, 1.75]

    // MARK: - Private Properties

    private var baseURL: URL?
    public private(set) var chapterNumber: Int
    private var chapterNameInternal: String
    private var reciterNameInternal: String
    private var reciterId: Int = 1
    private var timingSource: TimingSource = .mp3quran

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var endPlaybackObserver: Any?
    private var pendingSeekVerse: Int?
    private var pendingResumeVerse: Int?
    private var prefetchTask: Task<Void, Never>?
    private var prepareTask: Task<Void, Never>?
    private var lastPrefetchKey: String?

    private var shouldResumeAfterSeek = false
    private var shouldAutoStart = true

    // background/lock‑screen support is delegated to a helper so the view model
    // remains focused on playback logic. The helper lazily configures itself
    // when startIfNeeded(autoPlay:) is called.
    private var backgroundHelper: BackgroundPlaybackHelper?

    // MARK: - Init / Deinit

    public init(baseURL: URL? = nil, chapterNumber: Int = 0, chapterName: String = "", reciterName: String? = nil) {
        self.baseURL = baseURL
        self.chapterNumber = chapterNumber
        self.chapterNameInternal = chapterName
        self.reciterNameInternal = reciterName ?? ""
    }

    deinit {
        MainActor.assumeIsolated { cleanup() }
    }

    // MARK: - Derived Values

    public var isPlaying: Bool { playbackState == .playing }
    public var isLoading: Bool { playbackState == .loading }
    public var isPaused: Bool { playbackState == .paused }

    public var progress: Double {
        guard duration > 0, currentTime.isFinite, duration.isFinite else { return 0 }
        let ratio = currentTime / duration
        return min(max(ratio, 0), 1)
    }

    public var remainingTime: Double {
        guard duration.isFinite, currentTime.isFinite else { return 0 }
        return max(duration - currentTime, 0)
    }

    public var errorMessage: String? {
        if case let .failed(message) = playbackState {
            return message
        }
        return nil
    }

    public var hasValidConfiguration: Bool {
        chapterNumber > 0 && (timingSourceIsItqanOnly ? true : baseURL != nil)
    }

    private var timingSourceIsItqanOnly: Bool {
        if case .itqan = timingSource { return true }
        return false
    }

    @discardableResult
    public func configureIfNeeded(
        baseURL: URL,
        chapterNumber: Int,
        chapterName: String,
        reciterName: String,
        reciterId: Int? = nil,
        timingSource: TimingSource? = nil
    ) -> Bool {
        let baseURLChanged = self.baseURL != baseURL
        let chapterChanged = self.chapterNumber != chapterNumber || chapterNameInternal != chapterName
        let reciterChanged = reciterNameInternal != reciterName
        let reciterIdChanged = reciterId.map { $0 > 0 && $0 != self.reciterId } ?? false
        let timingSourceChanged = timingSource.map { $0 != self.timingSource } ?? false

        if baseURLChanged {
            self.baseURL = baseURL
        }

        if reciterChanged {
            reciterNameInternal = reciterName
        }

        if let reciterId = reciterId, reciterId > 0 {
            self.reciterId = reciterId
        }

        if let timingSource {
            self.timingSource = timingSource
        }

        if chapterChanged {
            updateChapter(number: chapterNumber, name: chapterName)
        }

        if !chapterChanged, (reciterIdChanged || timingSourceChanged) {
            prefetchChapterTimingIfNeeded()
        }

        return baseURLChanged || chapterChanged || reciterChanged || reciterIdChanged || timingSourceChanged
    }

    // MARK: - Lifecycle

    public func startIfNeeded(autoPlay: Bool = true) {
        shouldAutoStart = autoPlay

        guard hasValidConfiguration else {
            playbackState = .failed(String(localized: "Audio playback is not configured."))
            return
        }

        ensureBackgroundSupport()

        switch playbackState {
        case .idle, .failed:
            preparePlayer(autoPlay: autoPlay)
        case .paused, .ready, .finished:
            if autoPlay {
                play()
            }
        case .loading, .playing:
            break
        }
    }

    public func stop() {
        cleanup()
        cleanupBackgroundHelper()
        playbackState = .idle
        currentTime = 0
        duration = 0
        currentVerseNumber = nil
    }

    public func updateChapter(number: Int, name: String) {
        guard number != chapterNumber || name != chapterNameInternal else { return }
        chapterNumber = number
        chapterNameInternal = name
        stop()
        prefetchChapterTimingIfNeeded()
    }
    
    public func updateReciter(
        baseURL: URL,
        reciterName: String,
        reciterId: Int? = nil,
        timingSource: TimingSource? = nil
    ) {
        let reciterIdChanged = reciterId.map { $0 != self.reciterId } ?? false
        let timingSourceChanged = timingSource.map { $0 != self.timingSource } ?? false
        guard baseURL != self.baseURL || reciterName != reciterNameInternal || reciterIdChanged || timingSourceChanged else { return }

        let previousState = playbackState
        let resumeVerse = currentVerseNumber
        let previousTime = currentTime
        let shouldAutoPlay = previousState == .playing

        self.baseURL = baseURL
        self.reciterNameInternal = reciterName
        if let reciterId {
            self.reciterId = reciterId
        }
        if let timingSource {
            self.timingSource = timingSource
        }

        prefetchChapterTimingIfNeeded()

        pendingSeekVerse = nil

        switch previousState {
        case .playing, .paused, .ready:
            stop()

            if let resumeVerse {
                currentVerseNumber = resumeVerse
                pendingResumeVerse = shouldAutoPlay ? resumeVerse : nil
                pendingSeekVerse = shouldAutoPlay ? nil : resumeVerse

                if let timing = AyahTimingService.shared.getTiming(
                    for: self.reciterId,
                    surahId: chapterNumber,
                    ayahId: resumeVerse
                ) {
                    currentTime = Double(timing.start) / 1000.0
                } else {
                    currentTime = previousTime
                }
            } else {
                pendingResumeVerse = nil
                pendingSeekVerse = nil
                currentTime = previousTime
            }

            startIfNeeded(autoPlay: shouldAutoPlay)
        default:
            break
        }
    }
    
    /// Get the current verse being played based on timing
    private func updateCurrentVerse() {
        guard chapterNumber > 0, reciterId > 0 else { return }
        
        // Convert current time from seconds to milliseconds
        let currentTimeMs = Int(currentTime * 1000)
        
        // Get the current verse from timing service
        let newVerseNumber = AyahTimingService.shared.getCurrentVerse(
            for: reciterId,
            surahId: chapterNumber,
            currentTimeMs: currentTimeMs
        )
        // Only update if the verse has changed
        if newVerseNumber != currentVerseNumber {
            currentVerseNumber = newVerseNumber
        }
    }

    // MARK: - Playback Controls

    private func ensureBackgroundSupport() {
        if backgroundHelper == nil {
            let helper = BackgroundPlaybackHelper()
            helper.attach(to: self)
            backgroundHelper = helper
        }
    }

    // when detached or deinit, ensure helper is cleaned up
    private func cleanupBackgroundHelper() {
        backgroundHelper?.detach()
        backgroundHelper = nil
    }

    public func togglePlayback() {
        switch playbackState {
        case .idle, .failed:
            startIfNeeded(autoPlay: true)
        case .loading:
            break
        case .ready, .paused, .finished:
            play()
        case .playing:
            pause()
        }
    }

    public func play() {
        guard let player else {
            preparePlayer(autoPlay: true)
            return
        }

        if let pending = pendingResumeVerse,
           let timing = AyahTimingService.shared.getTiming(for: reciterId, surahId: chapterNumber, ayahId: pending) {
            let targetSeconds = Double(timing.start) / 1000.0
            pendingResumeVerse = nil
            seek(to: targetSeconds) { [weak self] in
                guard let self, let player = self.player else { return }
                player.playImmediately(atRate: self.playbackRate)
                self.playbackState = .playing
            }
            return
        }

        player.playImmediately(atRate: playbackRate)
        playbackState = .playing
    }

    public func pause() {
        guard let player, playbackState == .playing else { return }
        player.pause()
        playbackState = .paused
    }

    public func cyclePlaybackRate() {
        let currentIndex = playbackRates.firstIndex(of: playbackRate) ?? 1
        let nextIndex = (currentIndex + 1) % playbackRates.count
        playbackRate = playbackRates[nextIndex]

        if playbackState == .playing {
            player?.rate = playbackRate
        }
    }

    // MARK: - Verse Navigation

    /// Seek to a specific verse within the current chapter using timing data
    @discardableResult
    public func seekToVerse(_ verseNumber: Int) -> Bool {
        guard verseNumber > 0, chapterNumber > 0, reciterId > 0 else { return false }
        guard let timing = AyahTimingService.shared.getTiming(
            for: reciterId,
            surahId: chapterNumber,
            ayahId: verseNumber
        ) else { return false }

        let targetSeconds = Double(timing.start) / 1000.0

        // If player is not ready yet, queue seek and initialize without autoplay
        guard let _ = player else {
            pendingSeekVerse = verseNumber
            startIfNeeded(autoPlay: false)
            return true
        }

        let shouldResume = isPlaying
        if shouldResume { pause() }
        seek(to: targetSeconds) { [weak self] in
            guard let self else { return }
            // Ensure highlight updates even when paused
            self.updateCurrentVerse()
            if shouldResume { self.play() }
        }
        return true
    }

    /// Seek to the next verse based on currentVerseNumber and chapter timing bounds
    @discardableResult
    public func seekToNextVerse() -> Bool {
        guard chapterNumber > 0, reciterId > 0 else { return false }
        guard let timings = AyahTimingService.shared.getChapterTimings(
            for: reciterId,
            surahId: chapterNumber
        ) else { return false }

        let sortedAyahs = timings.map { $0.ayah }.sorted()
        guard let lastAyah = sortedAyahs.last else { return false }
        let current = currentVerseNumber ?? sortedAyahs.first ?? 1
        let nextAyah = min(current + 1, lastAyah)
        if nextAyah != current {
            if isPlaying {
                return seekToVerse(nextAyah)
            } else {
                setPreviewVerse(nextAyah)
                return true
            }
        }
        return false
    }

    /// Seek to the previous verse based on currentVerseNumber and chapter timing bounds
    @discardableResult
    public func seekToPreviousVerse() -> Bool {
        guard chapterNumber > 0, reciterId > 0 else { return false }
        guard let timings = AyahTimingService.shared.getChapterTimings(
            for: reciterId,
            surahId: chapterNumber
        ) else { return false }

        let sortedAyahs = timings.map { $0.ayah }.sorted()
        guard let firstAyah = sortedAyahs.first else { return false }
        let current = currentVerseNumber ?? firstAyah
        let previousAyah = max(current - 1, firstAyah)
        if previousAyah != current {
            if isPlaying {
                return seekToVerse(previousAyah)
            } else {
                setPreviewVerse(previousAyah)
                return true
            }
        }
        return false
    }

    public func toggleRepeat() {
        isRepeatEnabled.toggle()
    }

    // Preview a verse when paused: update highlight and defer seek to play()
    public func setPreviewVerse(_ verseNumber: Int) {
        guard verseNumber > 0 else { return }
        currentVerseNumber = verseNumber
        pendingResumeVerse = verseNumber
    }

    public func beginScrubbing() {
        guard !isScrubbing, duration > 0 else { return }
        shouldResumeAfterSeek = isPlaying
        pause()
        isScrubbing = true
    }

    public func updateScrubbing(progress: Double) {
        guard isScrubbing else { return }
        let clamped = min(max(progress, 0), 1)
        currentTime = clamped * duration
    }

    public func endScrubbing(progress: Double) {
        guard isScrubbing else { return }
        let clamped = min(max(progress, 0), 1)
        let targetSeconds = clamped * duration
        isScrubbing = false

        seek(to: targetSeconds) { [weak self] in
            guard let self else { return }
            if self.shouldResumeAfterSeek {
                self.play()
            }
        }
    }

    // MARK: - Private Helpers

    private func preparePlayer(autoPlay: Bool) {
        cleanup()
        playbackState = .loading
        shouldAutoStart = autoPlay
        prefetchChapterTimingIfNeeded()

        prepareTask = Task { [weak self] in
            guard let self else { return }
            do {
                let audioURL = try await self.resolveAudioURLForPlayback()
                guard !Task.isCancelled else { return }
                self.setupPlayer(with: audioURL)
            } catch {
                if error is CancellationError || Task.isCancelled { return }
                self.playbackState = .failed(error.localizedDescription)
            }
        }
    }

    private func prefetchChapterTimingIfNeeded() {
        guard chapterNumber > 0, reciterId > 0 else { return }
        guard case .both = timingSource else { return }

        let currentReciterId = reciterId
        let currentChapterNumber = chapterNumber
        let prefetchKey = "\(currentReciterId)-\(currentChapterNumber)"

        if lastPrefetchKey == prefetchKey, prefetchTask != nil {
            return
        }

        prefetchTask?.cancel()
        lastPrefetchKey = prefetchKey
        prefetchTask = Task { [weak self] in
            _ = await AyahTimingService.shared.refreshChapterTimings(for: currentReciterId, surahId: currentChapterNumber)
            await MainActor.run {
                guard let self else { return }
                if self.lastPrefetchKey == prefetchKey {
                    self.prefetchTask = nil
                }
            }
        }
    }

    private func resolveAudioURLForPlayback() async throws -> URL {
        switch timingSource {
        case .itqan:
            guard let audioURL = await AyahTimingService.shared.refreshChapterTimings(for: reciterId, surahId: chapterNumber)
                ?? AyahTimingService.shared.getRemoteAudioURL(for: reciterId, surahId: chapterNumber) else {
                throw TimingProviderError.missingData
            }
            return audioURL
        case .both, .mp3quran:
            guard let baseURL else {
                throw TimingProviderError.invalidURL
            }
            let chapterPathComponent = String(format: "%03d.mp3", chapterNumber)
            return baseURL.appendingPathComponent(chapterPathComponent)
        case .none:
            throw TimingProviderError.unsupportedTimingSource
        }
    }

    private func setupPlayer(with audioURL: URL) {
        AppLogger.shared.info("QuranPlayer: Loading audio from URL: \(audioURL.absoluteString)", category: .network)

        let asset = AVURLAsset(url: audioURL)
        let playerItem = AVPlayerItem(asset: asset)

        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player

        observeStatus(for: playerItem)
        observeTimeControl(for: player)
        observePeriodicTime(for: player)
        observeCompletion(for: playerItem)
    }

    private func observeStatus(for item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self.updateDuration(from: item)
                    if self.shouldAutoStart {
                        self.play()
                    } else {
                        self.playbackState = .ready
                    }
                    // If a pending seek was requested before readiness, perform it now
                    if let pending = self.pendingSeekVerse {
                        self.pendingSeekVerse = nil
                        _ = self.seekToVerse(pending)
                    }
                case .failed:
                    self.playbackState = .failed(item.error?.localizedDescription ?? String(localized: "Unable to load audio."))
                    self.isBuffering = false
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func observeTimeControl(for player: AVPlayer) {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            guard let self else { return }
            Task { @MainActor in
                switch player.timeControlStatus {
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                default:
                    self.isBuffering = false
                }
            }
        }
    }

    private func observePeriodicTime(for player: AVPlayer) {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: nil) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }

                let seconds = CMTimeGetSeconds(time)
                if !self.isScrubbing, seconds.isFinite {
                    self.currentTime = seconds
                    // Update the current verse based on playback time
                    self.updateCurrentVerse()
                }

                if let item = self.player?.currentItem {
                    self.updateDuration(from: item)
                }
            }
        }
    }

    private func observeCompletion(for item: AVPlayerItem) {
        endPlaybackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if self.isRepeatEnabled {
                    self.seek(to: 0) { [weak self] in
                        self?.play()
                    }
                } else {
                    self.playbackState = .finished
                }
            }
        }
    }

    private func seek(to seconds: Double, completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard let player else { return }
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)

        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, completion] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = seconds
                completion?()
            }
        }
    }

    private func updateDuration(from item: AVPlayerItem) {
        let itemDuration = CMTimeGetSeconds(item.duration)
        if itemDuration.isFinite, itemDuration > 0 {
            duration = itemDuration
        }
    }

    private func cleanup() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }

        statusObservation?.invalidate()
        statusObservation = nil

        timeControlObservation?.invalidate()
        timeControlObservation = nil

        if let endPlaybackObserver {
            NotificationCenter.default.removeObserver(endPlaybackObserver)
            self.endPlaybackObserver = nil
        }

        player?.pause()
        player = nil
        isBuffering = false
        prepareTask?.cancel()
        prepareTask = nil
        prefetchTask?.cancel()
        prefetchTask = nil
        lastPrefetchKey = nil
    }
}

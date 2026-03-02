//
//  AudioSessionManager.swift
//  MushafImad
//
//  Centralizes AVAudioSession configuration and interruption handling for
//  background audio playback. The view model and example app interact with
//  this singleton to prepare the audio session and respond to system events.
//

// AVAudioSession is only available on iOS/tvOS/macCatalyst. Provide a guarded
// implementation that uses AVFoundation where supported and a lightweight
// no-op stub for other platforms (macOS) so cross-platform callers compile.

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
  import AVFoundation

  @MainActor
  public final class AudioSessionManager {
    public static let shared = AudioSessionManager()

    private init() {}

    /// Configures the shared AVAudioSession for long‑lived playback. This should
    /// be invoked early in the app’s lifecycle, typically at launch or when the
    /// first player is created.
    public func configureAudioSession() throws {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [])
      try session.setActive(true, options: .notifyOthersOnDeactivation)
      AppLogger.shared.info("Audio Session configured", category: .audio)
    }

    /// Registers handlers for audio session interruptions (incoming calls,
    /// system alerts, etc.). The caller is responsible for pausing/resuming the
    /// active player when these closures fire.
    private var interruptionObserver: Any?
	
	/// Sets up handlers for audio session interruptions (incoming calls, system alerts, etc.). The caller is responsible for pausing/resuming the active player when these closures fire.
    public func setupInterruptionHandling(
      onInterruptionBegan: @escaping () -> Void,
      onInterruptionEnded: @escaping () -> Void
    ) {
      // remove existing observer if previously registered
      if let obs = interruptionObserver {
        NotificationCenter.default.removeObserver(obs)
        interruptionObserver = nil
      }

      interruptionObserver = NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: AVAudioSession.sharedInstance(),
        queue: .main
      ) { notification in
        guard let typeRaw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
        else {
          return
        }

        switch type {
        case .began:
          onInterruptionBegan()
        case .ended:
          let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
          let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw ?? 0)
          let shouldResume = options.contains(.shouldResume)
          if shouldResume {
            onInterruptionEnded()
          }
        @unknown default:
          break
        }
      }
    }

    @MainActor
    deinit {
      if let obs = interruptionObserver {
        NotificationCenter.default.removeObserver(obs)
      }
    }
  }
#else
  @MainActor
  public final class AudioSessionManager {
    // Keep a matching API on unsupported platforms (macOS) so callers compile.
    public static let shared = AudioSessionManager()
    private init() {}

    public func configureAudioSession() throws {
      // No-op on macOS / unsupported platforms.
    }

    public func setupInterruptionHandling(
      onInterruptionBegan: @escaping () -> Void,
      onInterruptionEnded: @escaping () -> Void
    ) {
      // No-op on macOS / unsupported platforms.
    }
  }
#endif

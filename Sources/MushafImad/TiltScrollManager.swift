//
//  TiltScrollManager.swift
//  MushafImad
//
//  Created by Assistant on 15/02/2026.
//

import SwiftUI
import CoreMotion
import Combine

/// Manages the tilt-to-scroll functionality using CoreMotion.
@MainActor
public class TiltScrollManager: ObservableObject {
    public enum ScrollAxis {
        case vertical
        case horizontal
    }

    public enum TiltProfile {
        case defaultPaged
        case textContinuous
    }

    private let motionManager = CMMotionManager()
    private var displayLink: CADisplayLink?
    private var settingsCancellable: AnyCancellable?
    // Configurable settings
    @AppStorage("tilt_scroll_enabled") public var isEnabled: Bool = false {
        didSet {
            updateMonitoringState()
        }
    }
    
    @AppStorage("tilt_sensitivity") public var sensitivity: Double = 2.5
    
    private weak var scrollView: UIScrollView?
    private var scrollAxis: ScrollAxis = .vertical
    private var tiltProfile: TiltProfile = .defaultPaged
    private var textNeutralPitch: Double?
    
    private var scrollVelocity: CGFloat = 0
    private let speedMultiplier: CGFloat = 0.35
    private let maxVelocity: CGFloat = 14
    
    public init() {
        settingsCancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMonitoringState()
            }
        updateMonitoringState()
    }
    
    public func setScrollView(_ scrollView: UIScrollView) {
        self.scrollView = scrollView
    }

    public func setScrollAxis(_ axis: ScrollAxis) {
        scrollAxis = axis
    }

    public func setTiltProfile(_ profile: TiltProfile) {
        if tiltProfile != profile {
            textNeutralPitch = nil
        }
        tiltProfile = profile
    }
    
    private var isMonitoring = false
    
    private func updateMonitoringState() {
        if isEnabled, !isMonitoring {
            startMonitoring()
        } else if !isEnabled, isMonitoring {
            stopMonitoring()
        }
    }
    
    private func startMonitoring() {
        guard !isMonitoring, motionManager.isDeviceMotionAvailable else {
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                return
            }
            MainActor.assumeIsolated { [weak self] in
                guard let self else { return }
                self.processMotion(motion)
            }
        }
        
        startDisplayLink()
        isMonitoring = true
    }
    
    private func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        stopDisplayLink()
        scrollVelocity = 0
        isMonitoring = false
    }
    
    public func activate() {
        updateMonitoringState()
    }
    
    public func deactivate() {
        stopMonitoring()
        isMonitoring = false
        textNeutralPitch = nil
    }
    
    private final class DisplayLinkProxy: NSObject {
        weak var manager: TiltScrollManager?
        @MainActor @objc func step() { manager?.updateScrollPosition() }
    }
    
    private func startDisplayLink() {
        stopDisplayLink()
        let proxy = DisplayLinkProxy()
        proxy.manager = self
        let displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.step))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func processMotion(_ motion: CMDeviceMotion) {
        if tiltProfile == .textContinuous, scrollAxis == .vertical {
            processTextContinuousMotion(motion)
            return
        }

        let pitch = motion.attitude.pitch
        let roll = motion.attitude.roll
        let tiltAngle: Double
        let centerAngle: Double
        let tolerance: Double
        let scale: Double

        if scrollAxis == .vertical {
            tiltAngle = pitch
            centerAngle = 25.0 * .pi / 180.0
            tolerance = 10.0 * .pi / 180.0
            scale = 50.0
        } else {
            tiltAngle = roll
            centerAngle = 0.0
            tolerance = 5.0 * .pi / 180.0
            scale = 80.0
        }

        var targetVelocity: CGFloat = 0
        
        if tiltAngle > (centerAngle + tolerance) {
            let delta = tiltAngle - (centerAngle + tolerance)
            targetVelocity = CGFloat(delta * sensitivity * scale)
        } else if tiltAngle < (centerAngle - tolerance) {
            let delta = (centerAngle - tolerance) - tiltAngle
            targetVelocity = -CGFloat(delta * sensitivity * scale)
        }

        // For horizontal axis, invert sign so:
        // tilt right -> scroll right, tilt left -> scroll left.
        if scrollAxis == .horizontal {
            targetVelocity = -targetVelocity
        }

        targetVelocity *= speedMultiplier
        targetVelocity = max(-maxVelocity, min(targetVelocity, maxVelocity))
        
        
        // Smooth the velocity
        scrollVelocity = scrollVelocity * 0.9 + targetVelocity * 0.1
        
        // Dead stop if very small
        if abs(scrollVelocity) < 0.1 {
            scrollVelocity = 0
        }
    }

    /// Text profile:
    /// - forward tilt (top down) -> content moves up (like swipe up)
    /// - backward tilt (top up) -> content moves down (like swipe down)
    /// Neutral is near upright reading posture, with a dead-zone to avoid jitter.
    private func processTextContinuousMotion(_ motion: CMDeviceMotion) {
        let pitch = motion.attitude.pitch
        if textNeutralPitch == nil {
            textNeutralPitch = pitch
        }
        let neutralPitch = textNeutralPitch ?? pitch
        let deadZone = 6.0 * .pi / 180.0
        let delta = pitch - neutralPitch
        let effectiveTilt = abs(delta) > deadZone
            ? (delta - deadZone * (delta > 0 ? 1 : -1))
            : 0

        let scale: Double = 24.0
        var targetVelocity = CGFloat(effectiveTilt * sensitivity * scale)
        targetVelocity *= speedMultiplier
        targetVelocity = max(-maxVelocity, min(targetVelocity, maxVelocity))

        scrollVelocity = scrollVelocity * 0.88 + targetVelocity * 0.12
        if abs(scrollVelocity) < 0.1 {
            scrollVelocity = 0
        }
    }
    
    private func updateScrollPosition() {
        guard let scrollView = scrollView else {
            // print("[TiltScrollManager] No ScrollView to scroll")
            return
        }
        
        guard scrollVelocity != 0 else { return }
        
        // Check if user is touching?
        // scrollView.isDragging might be true if user is holding it.
        // We should pause if user is interacting.
        if scrollView.isDragging || scrollView.isTracking {
            return
        }
        
        // print("[TiltScrollManager] Scrolling by \(scrollVelocity)")
        if scrollAxis == .vertical {
            let newOffset = CGPoint(
                x: scrollView.contentOffset.x,
                y: scrollView.contentOffset.y + scrollVelocity
            )
            let maxOffsetY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            let clampedY = max(0, min(newOffset.y, maxOffsetY))

            if clampedY != scrollView.contentOffset.y {
                scrollView.setContentOffset(CGPoint(x: newOffset.x, y: clampedY), animated: false)
            }
        } else {
            let newOffset = CGPoint(
                x: scrollView.contentOffset.x + scrollVelocity,
                y: scrollView.contentOffset.y
            )
            let maxOffsetX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
            let clampedX = max(0, min(newOffset.x, maxOffsetX))

            if clampedX != scrollView.contentOffset.x {
                scrollView.setContentOffset(CGPoint(x: clampedX, y: newOffset.y), animated: false)
            }
        }
    }
}

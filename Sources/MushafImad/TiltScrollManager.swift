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
    private let motionManager = CMMotionManager()
    private var displayLink: CADisplayLink?
    private var settingsCancellable: AnyCancellable?
    // Configurable settings
    @AppStorage("tilt_scroll_enabled") public var isEnabled: Bool = false {
        didSet {
            updateMonitoringState()
        }
    }
    
    @AppStorage("tilt_sensitivity") public var sensitivity: Double = 5.0
    
    private weak var scrollView: UIScrollView?
    
    private var scrollVelocity: CGFloat = 0
    private let deadZone: Double = 5.0 * .pi / 180.0
    
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
    
    private func updateMonitoringState() {
        if isEnabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }
    
    private func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                return
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if Int(motion.timestamp * 10) % 20 == 0 {
                    let p = motion.attitude.pitch * 180 / .pi
                    print("[TiltScrollManager] Pitch: \(String(format: "%.1f", p))°")
                }
                self.processMotion(motion)
            }
        }
        
        startDisplayLink()
    }
    
    private func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        stopDisplayLink()
        scrollVelocity = 0
    }
    
    public func deactivate() {
        stopMonitoring()
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
        
        let pitch = motion.attitude.pitch
        let degrees = pitch * 180 / .pi
        
        var targetVelocity: CGFloat = 0
        let centerAngle = 25.0 * .pi / 180.0
        let tolerance = 10.0 * .pi / 180.0 // +/- 10 degrees deadzone
        
        
        if pitch > (centerAngle + tolerance) {
            let delta = pitch - (centerAngle + tolerance)
            targetVelocity = CGFloat(delta * sensitivity * 50.0) // Scaling factor
        } else if pitch < (centerAngle - tolerance) {
            let delta = (centerAngle - tolerance) - pitch
            targetVelocity = -CGFloat(delta * sensitivity * 50.0)
        } else {
            // print("[TiltScrollManager] Action: NONE (Deadzone)")
        }
        
        
        // Smooth the velocity
        scrollVelocity = scrollVelocity * 0.9 + targetVelocity * 0.1
        
        // Dead stop if very small
        if abs(scrollVelocity) < 0.1 {
            scrollVelocity = 0
        }
    }
    
    @objc private func updateScrollPosition() {
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
        
        let newOffset = CGPoint(
            x: scrollView.contentOffset.x,
            y: scrollView.contentOffset.y + scrollVelocity
        )
        
        let maxOffsetY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let clampedY = max(0, min(newOffset.y, maxOffsetY))
        
        if clampedY != scrollView.contentOffset.y {
            scrollView.setContentOffset(CGPoint(x: newOffset.x, y: clampedY), animated: false)
        }
    }
}

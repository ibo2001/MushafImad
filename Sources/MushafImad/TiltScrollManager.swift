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
    
    // Configurable settings
    @AppStorage("tilt_scroll_enabled") public var isEnabled: Bool = false {
        didSet {
            updateMonitoringState()
        }
    }
    
    @AppStorage("tilt_sensitivity") public var sensitivity: Double = 5.0 // Range: 1.0 to 10.0
    
    // The target scroll view to manipulate
    private weak var scrollView: UIScrollView?
    
    // Current scroll velocity
    private var scrollVelocity: CGFloat = 0
    
    // Neutral pitch angle (calibrated when scrolling starts or manually)
    // For simplicity, we'll assume a comfortable reading angle of ~45 degrees (pi/4) or calibrate on first activation.
    // Ideally, we might want to "zero" the sensor when the user enables the feature or taps a button.
    // For this V1, let's use a dynamic neutral point or a fixed offset.
    // A better approach for "Tilt-to-Scroll" is to consider the "current" angle as neutral when the user
    // touches the screen, but since this is hands-free, we need a refined logic.
    // Let's use a "dead zone" around a reference angle.
    // Or simpler: The user sets a "neutral" angle by holding the device steady for a moment?
    // Let's try a fixed reference for now: 60 degrees from flat is typical reading.
    // Actually, "zero" pitch is flat on table. 90 degrees is upright.
    // We'll use a relative approach: deviations from the angle at *start of scrolling*?
    // No, that requires a trigger.
    // Let's implement a "Dead Zone" logic. If pitch is between X and Y, no scroll.
    // Above Y -> Scroll Down. Below X -> Scroll Up.
    private let neutralPitch: Double = 45.0 * .pi / 180.0 // ~45 degrees
    private let deadZone: Double = 5.0 * .pi / 180.0 // +/- 5 degrees
    
    public init() {
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
        print("[TiltScrollManager] startMonitoring called")
        guard motionManager.isDeviceMotionAvailable else {
            print("[TiltScrollManager] Device Motion is NOT available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    print("[TiltScrollManager] Motion error: \(error)")
                }
                return
            }
            // Optional: Print pitch occasionally
             if Int(motion.timestamp * 10) % 20 == 0 {
                  let p = motion.attitude.pitch * 180 / .pi
                  print("[TiltScrollManager] Pitch: \(String(format: "%.1f", p))°")
             }
            self.processMotion(motion)
        }
        
        startDisplayLink()
    }
    
    private func stopMonitoring() {
        print("[TiltScrollManager] stopMonitoring called")
        motionManager.stopDeviceMotionUpdates()
        stopDisplayLink()
        scrollVelocity = 0
    }
    
    private func startDisplayLink() {
        stopDisplayLink()
        let displayLink = CADisplayLink(target: self, selector: #selector(updateScrollPosition))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func processMotion(_ motion: CMDeviceMotion) {
        // Optional: Print pitch occasionally
        if Int(motion.timestamp * 60) % 60 == 0 {
             print("[TiltScrollManager] Pitch (deg): \(motion.attitude.pitch * 180 / .pi)")
        }
        
        // Attitude pitch:
        // 0 is flat on table.
        // +pi/2 is upright (portrait).
        // -pi/2 is upside down.
        
        // We want:
        // Tilt AWAY (pitch decreases? No, pitch goes from 0 to 90 as you lift it up).
        // Wait, let's verify pitch behavior.
        // Flat table: pitch ~ 0.
        // Lift top up (portrait): pitch increases to pi/2.
        
        // User holds device at say 45 deg (0.78 rad).
        // user tilts moves "top away" -> larger angle (more vertical)? No, Top away means device goes flatter?
        // Let's visualize: User holding phone.
        // Top moves AWAY from user (tilting back): Screen points more towards ceiling. Pitch decreases towards 0. -> Scroll UP (content moves down, to see previous).
        // Top moves TOWARDS user (tilting forward): Screen points more towards user face/vertical. Pitch increases. -> Scroll DOWN (content moves up, to see next).
        
        // Let's reverse that logic based on standard "Tilt to Scroll" metaphors (like a request).
        // Usually:
        // Tilt Forward (top away): Scroll Down.
        // Tilt Back (top towards): Scroll Up.
        
        // Let's assume "Neutral" is the holding position.
        // We need a way to set Neutral. For now, let's just use the instantaneous pitch vs a smoothed average?
        // Or simpler:
        // Pitch > Neutral + DeadZone -> Scroll DOWN
        // Pitch < Neutral - DeadZone -> Scroll UP
        
        let pitch = motion.attitude.pitch
        let degrees = pitch * 180 / .pi
        
        // Let's treat 60 degrees as a "standard" holding angle?
        // Or maybe we can't hardcode it.
        // A better UX: When the user enables the feature, capture current attitude as "Neutral".
        // But for this pass, let's use a "smart" neutral.
        // Actually, let's just map relative changes if we wanted, but absolute is easier to implement first.
        
        // Let's use 60 degrees (approx 1.05 radians) as comfortable.
        // However, users vary wildly.
        // We might need a "Calibrate" button in settings.
        // For now, let's stick to a wide deadzone around 45-60.
        
        var targetVelocity: CGFloat = 0
        
        // Adjust these thresholds as needed or make them configurable
        // User reports ~10-20 degrees when holding.
        // Let's set Neutral to 30 degrees? Or maybe even 20?
        // A better approach is: Neutral = 30.
        // > 40 -> Down.
        // < 20 -> Up.
        
        let centerAngle = 25.0 * .pi / 180.0
        let tolerance = 10.0 * .pi / 180.0 // +/- 10 degrees deadzone
        
        // print("[TiltScrollManager] Pitch: \(Int(degrees))°, Neutral: 25°, Delta: \(Int(degrees - 25))")

        if pitch > (centerAngle + tolerance) {
            // More vertical -> Scroll Down
            let delta = pitch - (centerAngle + tolerance)
            targetVelocity = CGFloat(delta * sensitivity * 50.0) // Scaling factor
            // print("[TiltScrollManager] Action: SCROLL DOWN v=\(targetVelocity)")
        } else if pitch < (centerAngle - tolerance) {
            // Flatter -> Scroll Up
             let delta = (centerAngle - tolerance) - pitch
             targetVelocity = -CGFloat(delta * sensitivity * 50.0)
             // print("[TiltScrollManager] Action: SCROLL UP v=\(targetVelocity)")
        } else {
            // print("[TiltScrollManager] Action: NONE (Deadzone)")
        }
        
        if abs(targetVelocity) > 0.1 {
             // print("[TiltScrollManager] Target V: \(targetVelocity)")
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
              print("[TiltScrollManager] ScrollView is user-interacting")
            return
        }
        
        // print("[TiltScrollManager] Scrolling by \(scrollVelocity)")
        
        let newOffset = CGPoint(
            x: scrollView.contentOffset.x,
            y: scrollView.contentOffset.y + scrollVelocity
        )
        
        // Clamp to content size
        let maxOffsetY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let clampedY = max(0, min(newOffset.y, maxOffsetY))
        
        if clampedY != scrollView.contentOffset.y {
            scrollView.setContentOffset(CGPoint(x: newOffset.x, y: clampedY), animated: false)
        }
    }
}

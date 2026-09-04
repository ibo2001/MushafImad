//
//  EyeTrackingSettingsView.swift
//  MushafImad
//
//  User-facing settings panel for enabling and configuring
//  eye-tracking–assisted reading progress.
//
//  Created for Ramadan Impact — exploratory research (Issue #22).
//

import SwiftUI

/// Settings view that lets the user opt in to eye-tracking features
/// and configure reading parameters.
///
/// All settings are persisted via `@AppStorage` so they survive app restarts.
public struct EyeTrackingSettingsView: View {
    
    // MARK: - Settings
    
    @AppStorage("mushaf_imad_eye_tracking_enabled") private var isEnabled: Bool = false
    @AppStorage("mushaf_imad_eye_tracking_auto_highlight") private var autoHighlight: Bool = true
    @AppStorage("mushaf_imad_eye_tracking_auto_advance") private var autoAdvance: Bool = false
    @AppStorage("mushaf_imad_eye_tracking_show_overlay") private var showOverlay: Bool = false
    @AppStorage("mushaf_imad_eye_tracking_show_debug") private var showDebugInfo: Bool = false
    @AppStorage("mushaf_imad_eye_tracking_dwell_time") private var dwellTime: Double = 1.5
    @AppStorage("mushaf_imad_eye_tracking_reading_speed") private var readingSpeed: Double = 80
    @AppStorage("mushaf_imad_eye_tracking_use_fallback") private var useFallbackMode: Bool = false
    
    // MARK: - Environment
    
    @ObservedObject var coordinator: EyeTrackingCoordinator
    @Environment(\.dismiss) private var dismiss
    
    public init(coordinator: EyeTrackingCoordinator) {
        self.coordinator = coordinator
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - Experimental Banner
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "flask.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.purple)
                            .symbolEffect(.pulse, isActive: isEnabled)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Experimental Feature")
                                .font(.headline)
                            Text("Eye tracking is a research feature. Accuracy may vary by device and lighting conditions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Enable Toggle
                Section {
                    Toggle(isOn: $isEnabled) {
                        Label {
                            Text("Enable Eye Tracking")
                        } icon: {
                            Image(systemName: "eye.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .onChange(of: isEnabled) { _, newValue in
                        coordinator.setEnabled(newValue)
                    }
                    
                    // Device support status
                    HStack {
                        Text("Device Support")
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: coordinator.eyeTrackingService.isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(coordinator.eyeTrackingService.isSupported ? .green : .red)
                            Text(coordinator.eyeTrackingService.isSupported ? String(localized: "Supported") : String(localized: "Not Available"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if !coordinator.eyeTrackingService.isSupported {
                        Toggle(isOn: $useFallbackMode) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use Reading Estimation")
                                    Text("Estimates progress based on reading speed")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "speedometer")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                } header: {
                    Text("Tracking")
                } footer: {
                    Text("Eye tracking requires an iPhone with TrueDepth camera (iPhone X or later). Your camera data stays entirely on-device and is never stored or transmitted.")
                }
                
                // MARK: - Behavior
                Section {
                    Toggle(isOn: $autoHighlight) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-Highlight Verse")
                                Text("Highlights the verse you're reading")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "highlighter")
                                .foregroundStyle(.yellow)
                        }
                    }
                    
                    Toggle(isOn: $autoAdvance) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-Advance Page")
                                Text("Automatically flip to next page when finished reading")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.right.doc.on.clipboard")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("Behavior")
                }
                
                // MARK: - Tuning
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Dwell Time")
                            Spacer()
                            Text("\(String(format: "%.1f", dwellTime))s")
                                .foregroundStyle(.secondary)
                                .font(.subheadline.monospacedDigit())
                        }
                        
                        Slider(value: $dwellTime, in: 0.5...5.0, step: 0.5)
                            .tint(.green)
                        
                        Text("How long your gaze must rest on a verse before it's marked as read")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Reading Speed")
                            Spacer()
                            Text("\(Int(readingSpeed)) WPM")
                                .foregroundStyle(.secondary)
                                .font(.subheadline.monospacedDigit())
                        }
                        
                        Slider(value: $readingSpeed, in: 30...200, step: 10)
                            .tint(.blue)
                        
                        Text("Arabic words per minute (used for fallback estimation)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Tuning")
                }
                
                // MARK: - Developer
                Section {
                    Toggle(isOn: $showOverlay) {
                        Label {
                            Text("Show Tracking Overlay")
                        } icon: {
                            Image(systemName: "eye.trianglebadge.exclamationmark")
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    Toggle(isOn: $showDebugInfo) {
                        Label {
                            Text("Show Debug Info")
                        } icon: {
                            Image(systemName: "ladybug.fill")
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("These options are for testing and development. The overlay shows a dot where your gaze is estimated to be.")
                }
                
                // MARK: - Privacy
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("Privacy Commitment")
                                .fontWeight(.semibold)
                        } icon: {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            privacyItem(icon: "eye.slash", text: "Camera data is processed on-device only")
                            privacyItem(icon: "icloud.slash", text: "No gaze data is uploaded or stored")
                            privacyItem(icon: "hand.raised.fill", text: "Feature is entirely opt-in")
                            privacyItem(icon: "trash", text: "Stop tracking to immediately release camera")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(String(localized: "Eye Tracking"))
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func privacyItem(icon: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    EyeTrackingSettingsView(coordinator: EyeTrackingCoordinator())
}

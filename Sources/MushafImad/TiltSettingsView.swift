//
//  TiltSettingsView.swift
//  MushafImad
//
//  Created by Assistant on 15/02/2026.
//

import SwiftUI

public struct TiltSettingsView: View {
    @AppStorage("tilt_scroll_enabled") private var isEnabled: Bool = false
    @AppStorage("tilt_sensitivity") private var sensitivity: Double = 5.0
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Tilt to Scroll")) {
                Toggle("Enable Tilt Scrolling", isOn: $isEnabled)
                
                if isEnabled {
                    VStack(alignment: .leading) {
                        Text("Sensitivity")
                        Slider(value: $sensitivity, in: 1...10, step: 0.5) {
                            Text("Sensitivity")
                        } minimumValueLabel: {
                            Text("Slow")
                        } maximumValueLabel: {
                            Text("Fast")
                        }
                    }
                }
                
                Text("Tilt your device forward or backward to scroll automatically. Return to a neutral reading angle (~25°) to stop.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Scroll Settings")
    }
}

#Preview {
    TiltSettingsView()
}

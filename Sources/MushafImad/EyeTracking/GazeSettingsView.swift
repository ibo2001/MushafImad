//
//  GazeSettingsView.swift
//  MushafImad
//
//  Created by Tamer on 11/03/2026.
//

import SwiftUI

public struct GazeSettingsView: View {
    @AppStorage("gaze_tracking_enabled") private var isEnabled: Bool = false
    @AppStorage("gaze_auto_save") private var autoSaveProgress: Bool = true
    @AppStorage("gaze_auto_advance") private var autoAdvancePage: Bool = false
    @AppStorage("gaze_reading_speed") private var readingSpeed: Double = 4.0

    public init() {}

    public var body: some View {
        Form {
            Section(header: Text("Reading Progress Tracking")) {
                Toggle("Enable Reading Tracker", isOn: $isEnabled)

                if isEnabled {
                    VStack(alignment: .leading) {
                        Text("Reading Speed")
                        Slider(
                            value: $readingSpeed,
                            in: 2...10,
                            step: 0.5
                        ) {
                            Text("Reading Speed")
                        } minimumValueLabel: {
                            Text("Fast")
                        } maximumValueLabel: {
                            Text("Slow")
                        }
                    }

                    Toggle("Auto-save Progress", isOn: $autoSaveProgress)

                    Toggle("Auto-advance Page", isOn: $autoAdvancePage)
                }

                Text("Estimates your reading position based on time spent on each page. All data stays on your device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Reading Tracker")
    }
}

#Preview {
    GazeSettingsView()
}

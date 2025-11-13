//
//  Untitled.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 04/11/2025.
//

import SwiftUI

extension Double {
    var formatTime: String {
        guard self.isFinite else { return "00:00" }
        let clamped = max(self, 0)
        let hours = Int(clamped) / 3600
        let minutes = (Int(clamped) % 3600) / 60
        let seconds = Int(clamped) % 60
        
        if hours > 0 {
            // Show hours only if there is at least 1 hour
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            // Otherwise, keep the simple mm:ss format
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

//
//  Color+Extension.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 02/11/2025.
//

import SwiftUI

extension Color {
    @MainActor private static func fromAsset(_ name: String) -> Color { MushafAssets.color(named: name) }
    
    @MainActor public static var brand900: Color { fromAsset("Brand 900") }
    @MainActor public static var brand500: Color { fromAsset("Brand 500") }
    @MainActor public static var brand100: Color { fromAsset("Brand 100") }
    
    @MainActor public static var accent900: Color { fromAsset("Accent 900") }
    @MainActor public static var accent700: Color { fromAsset("Accent 700") }
    @MainActor public static var accent500: Color { fromAsset("Accent 500") }
    @MainActor public static var accent100: Color { fromAsset("Accent 100") }
    
    @MainActor public static var naturalWhite: Color { fromAsset("Natural White") }
    @MainActor public static var naturalBlack: Color { fromAsset("Natural Black") }
    @MainActor public static var naturalGray: Color { fromAsset("Natural Gray") }
    
    @MainActor public static var gentleSage: Color { fromAsset("Gentle Sage") }
    @MainActor public static var lavenderGray: Color { fromAsset("Lavender Gray") }
    @MainActor public static var mintCalm: Color { fromAsset("Mint Calm") }
    @MainActor public static var oliveMist: Color { fromAsset("Olive Mist") }
    @MainActor public static var softVanilla: Color { fromAsset("Soft Vanilla") }
    @MainActor public static var quran: Color { fromAsset("Quran") }
    
    /// Initialize a Color from a hex string (e.g., "#F9F9F9" or "F9F9F9")
    /// - Parameter hex: The hex color string with or without the # prefix
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    public static let chapterListGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(hex: "#E0F1EA"), location: 0.0),
            .init(color: Color(hex: "#E4F0DF"), location: 0.5),
            .init(color: Color(hex: "#DDF1D3"), location: 1.0)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
}

public extension ShapeStyle where Self == Color {
    @MainActor static var brand900: Color { Color.brand900 }
    @MainActor static var brand500: Color { Color.brand500 }
    @MainActor static var brand100: Color { Color.brand100 }
    
    @MainActor static var accent900: Color { Color.accent900 }
    @MainActor static var accent700: Color { Color.accent700 }
    @MainActor static var accent500: Color { Color.accent500 }
    @MainActor static var accent100: Color { Color.accent100 }
    
    @MainActor static var naturalWhite: Color { Color.naturalWhite }
    @MainActor static var naturalBlack: Color { Color.naturalBlack }
    @MainActor static var naturalGray: Color { Color.naturalGray }
    
    @MainActor static var gentleSage: Color { Color.gentleSage }
    @MainActor static var lavenderGray: Color { Color.lavenderGray }
    @MainActor static var mintCalm: Color { Color.mintCalm }
    @MainActor static var oliveMist: Color { Color.oliveMist }
    @MainActor static var softVanilla: Color { Color.softVanilla }
    @MainActor static var quran: Color { Color.quran }
}

//
//  ReadingTheme.swift
//  MushafImad
//
//  Reading appearance model that stays independent from the system color scheme.
//

import SwiftUI

/// A complete reading appearance definition used by `MushafView`.
public struct ReadingTheme: Equatable {
    public let backgroundColor: Color
    public let textColor: Color

    public init(backgroundColor: Color, textColor: Color) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }

    public static let comfortable = ReadingTheme(
        backgroundColor: Color(hex: "#E4EFD9"),
        textColor: .naturalBlack
    )

    public static let calm = ReadingTheme(
        backgroundColor: Color(hex: "#E0F1EA"),
        textColor: .naturalBlack
    )

    public static let night = ReadingTheme(
        backgroundColor: Color(hex: "#2F352F"),
        textColor: .naturalWhite
    )

    public static let white = ReadingTheme(
        backgroundColor: Color(hex: "#FFFFFF"),
        textColor: .naturalBlack
    )
}

/// Built-in theme presets suitable for persistence in `AppStorage`.
public enum ReadingThemePreset: String, CaseIterable {
    case comfortable
    case calm
    case night
    case white

    public var theme: ReadingTheme {
        switch self {
        case .comfortable:
            .comfortable
        case .calm:
            .calm
        case .night:
            .night
        case .white:
            .white
        }
    }

    public var title: String {
        switch self {
        case .comfortable:
            String(localized: "Comfy")
        case .calm:
            String(localized: "Calm")
        case .night:
            String(localized: "Night")
        case .white:
            String(localized: "White")
        }
    }
}

private struct MushafReadingThemeKey: EnvironmentKey {
    static let defaultValue: ReadingTheme? = nil
}

public extension EnvironmentValues {
    /// Optional package-level reading theme override for `MushafView`.
    var mushafReadingTheme: ReadingTheme? {
        get { self[MushafReadingThemeKey.self] }
        set { self[MushafReadingThemeKey.self] = newValue }
    }
}

public extension View {
    /// Sets a subtree-wide reading theme for `MushafView` instances.
    func mushafReadingTheme(_ theme: ReadingTheme?) -> some View {
        environment(\.mushafReadingTheme, theme)
    }
}

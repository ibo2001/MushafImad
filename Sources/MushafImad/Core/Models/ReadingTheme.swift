//
//  ReadingTheme.swift
//  MushafImad
//
//  Reading appearance model that stays independent from the system color scheme.
//

import SwiftUI

/// A complete reading appearance definition used by `MushafView`.
public struct ReadingTheme {
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

/// Built-in reading theme presets persisted by `AppStorage("reading_theme")`.
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

private struct MushafReadingThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: ReadingTheme? = nil
}

public extension EnvironmentValues {
    /// Optional package-level reading theme override for `MushafView`.
    var mushafReadingTheme: ReadingTheme? {
        get { self[MushafReadingThemeEnvironmentKey.self] }
        set { self[MushafReadingThemeEnvironmentKey.self] = newValue }
    }
}

public extension View {
    /// Sets a subtree-wide reading theme for `MushafView` instances.
    func mushafReadingTheme(_ theme: ReadingTheme?) -> some View {
        environment(\.mushafReadingTheme, theme)
    }
}
//
//  ReadingTheme.swift
//  MushafImad
//
//  Created by Assistant on 07/04/2026.
//

import SwiftUI

/// Defines the visual appearance of the Mushaf reading surface.
///
/// This model is intentionally independent from system light/dark mode so the
/// reading experience can remain stable based on user preference.
public struct ReadingTheme: Equatable {
    public let backgroundColor: Color
    public let textColor: Color

    public init(backgroundColor: Color, textColor: Color) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }
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
            ReadingTheme(backgroundColor: Color(hex: "#E4EFD9"), textColor: .naturalBlack)
        case .calm:
            ReadingTheme(backgroundColor: Color(hex: "#E0F1EA"), textColor: .naturalBlack)
        case .night:
            ReadingTheme(backgroundColor: Color(hex: "#2F352F"), textColor: .naturalWhite)
        case .white:
            ReadingTheme(backgroundColor: Color(hex: "#FFFFFF"), textColor: .naturalBlack)
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
    var mushafReadingTheme: ReadingTheme? {
        get { self[MushafReadingThemeKey.self] }
        set { self[MushafReadingThemeKey.self] = newValue }
    }
}

public extension View {
    /// Sets a package-level reading theme for `MushafView` descendants.
    func mushafReadingTheme(_ theme: ReadingTheme) -> some View {
        environment(\.mushafReadingTheme, theme)
    }
}
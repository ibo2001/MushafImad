//
//  Fonts+Extension.swift
//  Mushaf
//
//  Created by Ibrahim Qraiqe on 29/10/2025.
//

import SwiftUI

extension Font {
    // MARK: - Quran Text Fonts
    static func chapterNames(size: CGFloat) -> Font {
        .custom(CustomFontName.chapterNames.rawValue, size: size)
    }
    /// Uthmanic Hafs font for Quranic text
    static func uthmanicHafs(size: CGFloat) -> Font {
        .custom(CustomFontName.uthmanicHafs.rawValue, size: size)
    }
    
    /// Uthmanic TN1 font for Quranic text (regular weight)
    static func uthmanicTN1(size: CGFloat) -> Font {
        .custom(CustomFontName.uthmanicTN1.rawValue, size: size)
    }
    
    /// Uthmanic TN1 font for Quranic text (bold weight)
    static func uthmanicTN1Bold(size: CGFloat) -> Font {
        .custom(CustomFontName.uthmanicTN1Bold.rawValue, size: size)
    }
    
    /// Hafs Smart font for Quranic text
    static func hafsSmart(size: CGFloat) -> Font {
        .custom(CustomFontName.hafsSmart.rawValue, size: size)
    }
    
    // MARK: - Quran Numbers & Titles
    
    /// Font for displaying ayah numbers
    static func quranNumbers(size: CGFloat) -> Font {
        .custom(CustomFontName.quranNumbers.rawValue, size: size)
    }
    
    /// Font for displaying Chapter titles
    static func quranTitles(size: CGFloat) -> Font {
        .custom(CustomFontName.quranTitles.rawValue, size: size)
    }
    
    // MARK: - UI Fonts
    
    /// Kitab font for UI text (regular weight)
    static func kitab(size: CGFloat) -> Font {
        .custom(CustomFontName.kitabRegular.rawValue, size: size)
    }
    
    /// Kitab font for UI text (bold weight)
    static func kitabBold(size: CGFloat) -> Font {
        .custom(CustomFontName.kitabBold.rawValue, size: size)
    }
    
    // Al-QuranAlKareem
    static func alQuranAlKareem(size: CGFloat) -> Font {
        .custom(CustomFontName.alQuranAlKareen.rawValue, size: size)
    }
}

// MARK: - Font Name Reference

enum CustomFontName: String {
    // Quranic Text Fonts (KFGQPC family)
    case uthmanicHafs = "KFGQPCHAFSUthmanicScript-Regula"
    case uthmanicTN1 = "KFGQPCUthmanTahaNaskh"
    case uthmanicTN1Bold = "KFGQPCUthmanTahaNaskh-Bold"
    case hafsSmart = "KFGQPCHafsSmart-Regular"
    
    // Numbers & Titles
    case quranNumbers = "QuranNumbers"
    case quranTitles = "QuranTitles"
    
    // UI Fonts
    case kitabRegular = "Kitab-Regular"
    case kitabBold = "Kitab-Bold"
    
    // Surah Names
    case chapterNames = "SurahNameEjazahstyle-Regular"
    
    // Al-QuranAlKareem
    case alQuranAlKareen = "Al-QuranAlKareem"
}

// MARK: - Font Debugging Utilities

#if DEBUG
extension Font {
    /// Logs all available font families and their font names.
    /// Use this to find the correct PostScript name for your custom fonts.
    /// Routed through AppLogger (category `.ui`, like FontRegistrar) instead of
    /// `print` so the output is filterable in Console.app and stays out of
    /// host apps' stdout.
    static func printAvailableFonts() {
        #if canImport(UIKit) && DEBUG
        AppLogger.shared.debug("=== Available Font Families ===", category: .ui)
        for family in UIFont.familyNames.sorted() {
            AppLogger.shared.debug("\nFamily: \(family)", category: .ui)
            for fontName in UIFont.fontNames(forFamilyName: family) {
                AppLogger.shared.debug("  - \(fontName)", category: .ui)
            }
        }
        AppLogger.shared.debug("\n=== Custom Fonts ===", category: .ui)
        let customFontFiles = ["SurahName.otf", "HafsSmart_08.ttf", "Kitab-Bold.ttf",
                               "Kitab-Regular.ttf", "QuranNumbers.ttf", "QuranTitles.ttf",
                               "UthmanicHafs1 Ver17.ttf", "UthmanTN1 Ver20.ttf", "UthmanTN1B Ver20.ttf"]
        for fontFile in customFontFiles {
            AppLogger.shared.debug("File: \(fontFile)", category: .ui)
        }
        #endif
    }
    
    /// Tests if a custom font is available
    static func isFontAvailable(_ fontName: String) -> Bool {
        #if canImport(UIKit)
        return UIFont(name: fontName, size: 12) != nil
        #else
        return false
        #endif
    }
}
#endif

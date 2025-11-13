//
//  FontRegistrar.swift
//  MushafImadSPM
//
//  Created by Assistant on 10/11/2025.
//

import Foundation
import CoreText

/// Helper that registers bundled Quran fonts with CoreText at runtime.
public enum FontRegistrar {
    private static let fontFileNames: [String] = [
        "SurahName.otf",
        "HafsSmart_08.ttf",
        "Kitab-Bold.ttf",
        "Kitab-Regular.ttf",
        "QuranNumbers.ttf",
        "QuranTitles.ttf",
        "UthmanicHafs1 Ver17.ttf",
        "UthmanTN1 Ver20.ttf",
        "UthmanTN1B Ver20.ttf",
        "Al-QuranAlKareem Regular.ttf"
    ]
    
    public static func registerFontsIfNeeded() {
        for fileName in fontFileNames {
            registerFontIfNeeded(named: fileName)
        }
    }
    
    private static func registerFontIfNeeded(named fileName: String) {
        let components = splitFileName(fileName)
        let searchDirectories: [String?] = [
            "Res/fonts",
            "Resources/Res/fonts",
            nil
        ]
        
        var resolvedURL: URL?
        for directory in searchDirectories {
            resolvedURL = Bundle.mushafResources.url(
                forResource: components.name,
                withExtension: components.ext,
                subdirectory: directory ?? nil
            )
            if resolvedURL != nil { break }
        }
        
        if resolvedURL == nil {
            resolvedURL = Bundle.mushafResources.url(forResource: fileName, withExtension: nil)
        }
        
        guard let url = resolvedURL else {
            AppLogger.shared.warn("Missing font resource: \(fileName)", category: .ui)
            return
        }
        
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        
        if !success {
            if let error = error?.takeUnretainedValue() {
                let description = CFErrorCopyDescription(error) as String
                AppLogger.shared.debug("Font \(fileName) registration skipped: \(description)", category: .ui)
            } else {
                AppLogger.shared.debug("Font \(fileName) registration skipped for unknown reason", category: .ui)
            }
        }
    }
    
    private static func splitFileName(_ fileName: String) -> (name: String, ext: String?) {
        let url = URL(fileURLWithPath: fileName)
        let ext = url.pathExtension.isEmpty ? nil : url.pathExtension
        return (url.deletingPathExtension().lastPathComponent, ext)
    }
}



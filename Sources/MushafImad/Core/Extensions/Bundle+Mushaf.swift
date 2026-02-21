//
//  Bundle+Mushaf.swift
//  MushafImadSPM
//
//  Created by Ibrahim Qraiqe  on 10/11/2025.
//

import Foundation

extension Bundle {
    static var mushafResources: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }

    /// Loads reciter IDs from `reciters_manifest.json` in this bundle.
    ///
    /// Returns an empty array and logs a warning if the file is missing or cannot be decoded.
    func reciterIds() -> [Int] {
        guard let url = url(forResource: "reciters_manifest", withExtension: "json") else {
            AppLogger.shared.warn("reciters_manifest.json not found in \(bundleIdentifier ?? "bundle")", category: .app)
            return []
        }
        struct Entry: Codable { let id: Int }
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            AppLogger.shared.warn("Failed to decode reciters_manifest.json", category: .app)
            return []
        }
        return entries.map { $0.id }
    }
}



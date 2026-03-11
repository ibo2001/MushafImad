//
//  GazeToVerseResolver.swift
//  MushafImad
//
//  Created by Tamer on 11/03/2026.
//

import Foundation
import RealmSwift

@MainActor
public final class GazeToVerseResolver {
    private let realmService = RealmService.shared

    public init() {}

    public struct ResolvedVerse: Sendable, Equatable {
        public let chapterNumber: Int
        public let verseNumber: Int
        public let verseID: Int
        public let confidence: Double
    }

    public func resolve(
        gazePoint: GazePoint,
        page: Int,
        mushafType: MushafType = .hafs1441
    ) -> ResolvedVerse? {
        guard let pageObject = realmService.getPage(number: page) else {
            return nil
        }

        let verses = pageObject.verses(for: mushafType)
        guard !verses.isEmpty else { return nil }

        let targetLine = gazePoint.line
        let gazeX = Float(gazePoint.x)

        var bestMatch: Verse?
        var bestDistance: Float = .greatestFiniteMagnitude

        for verse in verses {
            let highlights = verse.highlights(for: mushafType)
            for highlight in highlights where highlight.line == targetLine {
                let midX = (highlight.left + highlight.right) / 2.0
                let distance = abs(midX - gazeX)
                if distance < bestDistance {
                    bestDistance = distance
                    bestMatch = verse
                }
            }
        }

        // If no match on exact line, try adjacent lines
        if bestMatch == nil {
            for verse in verses {
                let highlights = verse.highlights(for: mushafType)
                for highlight in highlights {
                    let lineDiff = abs(highlight.line - targetLine)
                    guard lineDiff <= 1 else { continue }
                    let midX = (highlight.left + highlight.right) / 2.0
                    let distance = abs(midX - gazeX) + Float(lineDiff) * 0.5
                    if distance < bestDistance {
                        bestDistance = distance
                        bestMatch = verse
                    }
                }
            }
        }

        guard let match = bestMatch else { return nil }

        let distanceConfidence = Double(max(0, 1.0 - bestDistance))
        let combined = min(distanceConfidence * gazePoint.confidence, 1.0)

        return ResolvedVerse(
            chapterNumber: match.chapterNumber,
            verseNumber: match.number,
            verseID: match.verseID,
            confidence: combined
        )
    }
}

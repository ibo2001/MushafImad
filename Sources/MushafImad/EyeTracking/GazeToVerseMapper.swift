//
//  GazeToVerseMapper.swift
//  MushafImad
//
//  Maps screen-space gaze coordinates to Mushaf lines and verses
//  using the page layout metadata (VerseHighlight bounds).
//
//  Created for Ramadan Impact — exploratory research (Issue #22).
//

import Foundation
import SwiftUI

// MARK: - Mapped Gaze Result

/// The result of mapping a gaze point to a specific location in the Mushaf.
public struct MappedGazeResult: Equatable, Sendable {
    /// The line index (0–14) that the gaze falls on.
    public let lineIndex: Int
    
    /// The verse's identifier — useful for quick equality checks.
    public let verseID: Int?
    
    /// Confidence of the mapping (inherits from gaze + geometric proximity).
    public let confidence: Float
    
    /// The normalized position within the line (0 = top of line, 1 = bottom).
    public let lineProgress: CGFloat
    
    public static func == (lhs: MappedGazeResult, rhs: MappedGazeResult) -> Bool {
        lhs.lineIndex == rhs.lineIndex && lhs.verseID == rhs.verseID
    }
}

// MARK: - Gaze Mapper

/// Maps screen-space gaze coordinates to Mushaf page elements (lines and verses).
///
/// The Mushaf page layout consists of:
/// - 15 lines per page (indices 0–14)
/// - Each line has a fixed aspect ratio (1440:232)
/// - Verses have `VerseHighlight` objects with `left`, `right`, and `line` properties
///   that define their bounding region on the page
///
/// This mapper uses the page's geometry to determine which line and verse
/// the user is looking at.
@MainActor
internal final class GazeToVerseMapper: ObservableObject {
    
    // MARK: - Configuration
    
    /// The total number of lines per Mushaf page.
    public static let linesPerPage = 15
    
    /// Original line image dimensions.
    private static let originalLineWidth: CGFloat = 1440
    private static let originalLineHeight: CGFloat = 232

    /// Multiplier to match QuranPageView's internal line height scaling.
    /// QuranPageView uses a smaller factor in landscape because the lines sit
    /// inside a scroll view there rather than being fit to the screen.
    private static let portraitLineHeightScale: CGFloat = 0.73
    private static let landscapeLineHeightScale: CGFloat = 0.7

    /// How far past a verse's nearest edge, in normalized page-width units, a
    /// miss is still resolved to that verse. Deliberately wider than a single
    /// verse gap (about 0.2 for two half-width verses either side of centre):
    /// narrower and gaze jitter between adjacent verses would resolve to
    /// neither; wider and unrelated verses on a sparse line would start
    /// absorbing gazes that were never meant for them.
    private static let nearestVerseEdgeThreshold: Float = 0.25

    // MARK: - Page Geometry Cache

    /// Cached geometry for the current page, set when the page view measures itself.
    private var pageFrame: CGRect = .zero
    private var headerHeight: CGFloat = 0
    private var lineHeight: CGFloat = 0
    
    // MARK: - Public API
    
    /// Update the mapper with the current page's on-screen geometry.
    ///
    /// Call this whenever the page layout changes (rotation, page flip, etc.)
    ///
    /// - Parameters:
    ///   - frame: The on-screen frame of the page content area (excluding chrome).
    ///   - headerOffset: The height of the page header above the lines.
    ///   - isLandscape: Whether the page is currently rendered in landscape.
    ///     QuranPageView renders landscape lines inside a scroll view and
    ///     scales them by a different factor than portrait; this must match
    ///     whichever one the renderer is actually using, or line boundaries
    ///     drift and lines near the bottom stop mapping to anything.
    public func updatePageGeometry(frame: CGRect, headerOffset: CGFloat = 40, isLandscape: Bool = false) {
        self.pageFrame = frame
        self.headerHeight = headerOffset

        // Each line's height is derived from the available width, matching
        // QuranPageView, which always scales lines to fit the page's width.
        let availableWidth = frame.width
        let calculatedLineHeight = availableWidth / Self.originalLineWidth * Self.originalLineHeight
        let scale = isLandscape ? Self.landscapeLineHeightScale : Self.portraitLineHeightScale
        self.lineHeight = calculatedLineHeight * scale
    }
    
    /// Map a screen-space gaze point to a line and verse on the current page.
    ///
    /// - Parameters:
    ///   - gazePoint: The estimated gaze position in screen coordinates.
    ///   - verses: The verses on the current page (from `Page.verses1441`).
    ///   - scrollOffset: How far the page's content has scrolled past its top
    ///     edge. Portrait pages never scroll, so this is always 0 there.
    ///     Landscape pages render lines inside a vertical scroll view that is
    ///     taller than the viewport, so the same on-screen point corresponds
    ///     to a different line depending on scroll position — the caller
    ///     must supply it or every gaze below the first screenful of lines
    ///     will fail to map.
    /// - Returns: A `MappedGazeResult` if the gaze falls within the page area, nil otherwise.
    public func mapGazeToVerse(
        gazePoint: GazePoint,
        verses: [Verse],
        scrollOffset: CGFloat = 0
    ) -> MappedGazeResult? {
        let screenPos = gazePoint.screenPosition

        // Check if gaze is within the page's on-screen viewport.
        guard pageFrame.contains(screenPos) else {
            return nil
        }

        // Position relative to the page's top-left origin, shifted into
        // content space by the current scroll offset so a screen point maps
        // to the line actually under it rather than the line that would be
        // there if the page were scrolled to the top.
        let pageRelativeY = (screenPos.y - pageFrame.minY) + scrollOffset
        let pageRelativeX = screenPos.x - pageFrame.minX

        // The vertical band occupied by the rendered lines:
        //   top  = headerHeight (matches the PageHeaderView height passed by caller)
        //   bottom = top + lineHeight * linesPerPage
        guard lineHeight > 0 else { return nil }
        let lineBandTop: CGFloat = headerHeight
        let lineBandBottom: CGFloat = lineBandTop + lineHeight * CGFloat(Self.linesPerPage)

        // Return nil for header and footer regions — do NOT clamp into line 0 or 14
        guard pageRelativeY >= lineBandTop && pageRelativeY <= lineBandBottom else {
            return nil
        }

        // Determine which line the gaze falls on relative to the band start
        let relativeYInBand = pageRelativeY - lineBandTop
        let lineIndex = Int(relativeYInBand / lineHeight)
        
        // Safety clamp (should always be in range given the guard above)
        guard lineIndex >= 0 && lineIndex < Self.linesPerPage else {
            return nil
        }
        
        // Progress within the line (0 = top, 1 = bottom)
        let lineProgress = (relativeYInBand - CGFloat(lineIndex) * lineHeight) / lineHeight
        let clampedProgress = min(1.0, max(0.0, lineProgress))
        
        // Find the verse at this position (page uses RTL layout)
        let normalizedX = pageRelativeX / pageFrame.width
        
        let matchedVerse = findVerseAtPosition(
            normalizedX: Float(normalizedX),
            lineIndex: lineIndex,
            verses: verses
        )
        
        return MappedGazeResult(
            lineIndex: lineIndex,
            verseID: matchedVerse?.verseID,
            confidence: gazePoint.confidence,
            lineProgress: clampedProgress
        )
    }
    
    /// Estimate the current line based on scroll offset (for fallback mode).
    ///
    /// When eye tracking is unavailable, this provides a rough estimate
    /// based on time and reading speed.
    ///
    /// - Parameters:
    ///   - elapsedSeconds: Time the user has been on this page.
    ///   - wordsPerMinute: Estimated reading speed for Arabic text.
    ///   - totalWordsOnPage: Approximate word count for the page.
    /// - Returns: Estimated line index (0–14).
    public func estimateLineFromReadingTime(
        elapsedSeconds: TimeInterval,
        wordsPerMinute: Double = 80,
        totalWordsOnPage: Int = 150
    ) -> Int {
        let wordsPerSecond = wordsPerMinute / 60.0
        let wordsRead = wordsPerSecond * elapsedSeconds
        let fractionRead = wordsRead / Double(totalWordsOnPage)
        let estimatedLine = Int(fractionRead * Double(Self.linesPerPage))
        return min(Self.linesPerPage - 1, max(0, estimatedLine))
    }
    
    // MARK: - Private Helpers
    
    /// Find the verse whose highlight region contains the given normalized X position
    /// on the specified line.
    private func findVerseAtPosition(
        normalizedX: Float,
        lineIndex: Int,
        verses: [Verse]
    ) -> Verse? {
        // The highlight coordinates use RTL layout:
        // `left` and `right` are normalized positions where right > left
        // In RTL, the visual left corresponds to (1 - right) and visual right to (1 - left)
        
        var bestMatch: Verse?
        var smallestDistance: Float = .greatestFiniteMagnitude
        
        for verse in verses {
            let highlights = verse.highlights1441.filter { $0.line == lineIndex }
            
            for highlight in highlights {
                // Convert to visual coordinates (RTL)
                let visualLeft = 1.0 - highlight.right
                let visualRight = 1.0 - highlight.left
                
                // Check if the gaze X falls within this highlight's bounds
                if normalizedX >= visualLeft && normalizedX <= visualRight {
                    // Direct hit
                    return verse
                }

                // Track the closest verse in case there's no direct hit, measuring to
                // the nearest edge rather than the centre. Centre distance grows with
                // the highlight's own width, so a wide verse reads as "far away" even
                // when the gaze is sitting right beside it.
                let distance = max(0, max(visualLeft - normalizedX, normalizedX - visualRight))
                if distance < smallestDistance {
                    smallestDistance = distance
                    bestMatch = verse
                }
            }
        }

        // If we're within a reasonable distance of a verse's edge, return nearest
        if smallestDistance < Self.nearestVerseEdgeThreshold {
            return bestMatch
        }

        return nil
    }
}

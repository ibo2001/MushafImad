//
//  MushafPageGeometry.swift
//  MushafImad
//

import SwiftUI

/// A center point and size for placing a view via `.position(_:)` and `.frame(width:height:)`.
public struct MushafElementPlacement: Equatable {
    public let center: CGPoint
    public let size: CGSize

    public init(center: CGPoint, size: CGSize) {
        self.center = center
        self.size = size
    }
}

/// The single source of truth for where verses live on a rendered Mushaf line.
///
/// Mirrors the Realm geometry contract — `VerseHighlight` (line, left, right),
/// `VerseMarker` (line, centerX, centerY) and `ChapterHeader` (line, centerX,
/// centerY), all normalized floats mirrored for RTL as `1.0 - x` — into
/// concrete on-screen placements for a given line's container size. Every
/// interactive feature (verse hit-testing, the selection/playback highlight,
/// the ayah medallion, the surah name bar) reads from here, so swapping how a
/// page is *drawn* (see `MushafRenderSource`) can never change where verses
/// *are*.
public struct MushafPageGeometry: Equatable {
    /// The fixed pixel dimensions every canonical line is authored at.
    public static let lineImageSize = CGSize(width: 1440, height: 232)

    /// Every Mushaf page has exactly 15 lines, indexed 0...14.
    public static let lineIndices: ClosedRange<Int> = 0...14

    /// The on-screen size allotted to the line this geometry describes.
    public let containerSize: CGSize

    public init(containerSize: CGSize) {
        self.containerSize = containerSize
    }

    private static var imageAspect: CGFloat {
        lineImageSize.width / lineImageSize.height
    }

    /// Height the canonical line scales to once fit to the container's width,
    /// before any vertical crop to the container's (usually shorter) height.
    public var scaledImageHeight: CGFloat {
        containerSize.width / Self.imageAspect
    }

    /// How far the scaled line is cropped, top and bottom, to fit the container's height.
    public var cropOffset: CGFloat {
        (scaledImageHeight - containerSize.height) / 2
    }

    /// Scale factor from the canonical 1440pt-wide line to the container's width.
    /// Used to size line-relative overlays such as the ayah medallion.
    public var lineScale: CGFloat {
        containerSize.width / Self.lineImageSize.width
    }

    /// Mirrors a normalized x-coordinate for RTL layout.
    public static func mirroredX(_ x: Float) -> CGFloat {
        CGFloat(1.0 - x)
    }

    /// The on-screen center and size of a verse's highlight rect on this line.
    public func highlightPlacement(for highlight: VerseHighlight) -> MushafElementPlacement {
        let left = containerSize.width * Self.mirroredX(highlight.right)
        let right = containerSize.width * Self.mirroredX(highlight.left)
        let width = right - left
        let height = containerSize.height * 0.94
        return MushafElementPlacement(
            center: CGPoint(x: left + width / 2, y: height * 0.8),
            size: CGSize(width: width, height: height)
        )
    }

    /// The on-screen center of a verse's ayah medallion on this line.
    public func markerCenter(for marker: VerseMarker) -> CGPoint {
        let x = containerSize.width * Self.mirroredX(marker.centerX)
        let y = (scaledImageHeight * CGFloat(marker.centerY) - cropOffset) + 10
        return CGPoint(x: x, y: y)
    }

    /// The on-screen center and size of a surah name bar on this line.
    public func chapterBarPlacement(for header: ChapterHeader) -> MushafElementPlacement {
        let x = containerSize.width * Self.mirroredX(header.centerX)
        let y = (scaledImageHeight * CGFloat(header.centerY) - cropOffset) + 8
        return MushafElementPlacement(
            center: CGPoint(x: x, y: y),
            size: CGSize(width: containerSize.width * 0.9, height: scaledImageHeight * 0.8)
        )
    }
}

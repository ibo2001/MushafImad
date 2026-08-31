//
//  MushafRenderSource.swift
//  MushafImad
//

import SwiftUI

/// Produces the visual for one line of a Mushaf page.
///
/// A render source's only job is drawing pixels for the line it's given —
/// a line image today, potentially a cropped page image, an SVG, or
/// glyph-rendered text in the future. It:
///
/// - **Must** return content sized to fit `containerSize` (the box
///   `QuranPageView` has already laid out for this line).
/// - **Must** apply `.renderingMode(.template)` (or equivalent) to any
///   bitmap/vector artwork it draws, so `ReadingTheme` tinting keeps working.
/// - **Must not** know about verses, highlights, ayah medallions, surah name
///   bars, or any other interaction concern. That geometry always comes from
///   `MushafPageGeometry` and Realm, drawn by `QuranPageView` itself on top
///   of whatever the render source produces — never inside it. This is what
///   lets every render source inherit verse selection, tafseer, and
///   follow-the-reciter highlighting for free.
/// - **Must not** perform hit-testing or attach gestures; `QuranPageView`
///   disables hit-testing on the render source's output and owns all touch
///   handling itself.
///
/// The active source is read from `MushafRendering.configuration`, following
/// the same override pattern as `MushafAssets.configuration`.
@MainActor
public protocol MushafRenderSource {
    /// The visual for the line described by `context`.
    func lineView(_ context: MushafRenderContext) -> AnyView
}

/// What a render source needs to know to draw one line: which page, which
/// line (0...14), and the box it must fit within. A struct rather than loose
/// parameters so future axes (e.g. the 1405 layout in #74) can be added
/// without re-signing this public protocol requirement.
public struct MushafRenderContext {
    public let page: Int
    public let line: Int
    public let containerSize: CGSize

    public init(page: Int, line: Int, containerSize: CGSize) {
        self.page = page
        self.line = line
        self.containerSize = containerSize
    }
}

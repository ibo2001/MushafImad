//
//  LineImageRenderSource.swift
//  MushafImad
//

import SwiftUI

/// The default `MushafRenderSource`: draws the bundled per-line PNGs via
/// `QuranLineImageView`, reproducing the reader's original output exactly,
/// including `.renderingMode(.template)` for `ReadingTheme` tinting.
public struct LineImageRenderSource: MushafRenderSource {
    public init() {}

    public func lineView(page: Int, line: Int, containerSize: CGSize) -> AnyView {
        let geometry = MushafPageGeometry(containerSize: containerSize)
        return AnyView(
            QuranLineImageView(
                page: page,
                line: line + 1,
                imageAspect: MushafPageGeometry.lineImageSize.width / MushafPageGeometry.lineImageSize.height,
                containerWidth: containerSize.width,
                scaledImageHeight: geometry.scaledImageHeight
            )
        )
    }
}

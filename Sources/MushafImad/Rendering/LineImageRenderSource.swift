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

    public func lineView(_ context: MushafRenderContext) -> AnyView {
        let geometry = MushafPageGeometry(containerSize: context.containerSize)
        return AnyView(
            QuranLineImageView(
                page: context.page,
                line: context.line + 1,
                imageAspect: MushafPageGeometry.lineImageSize.width / MushafPageGeometry.lineImageSize.height,
                containerWidth: context.containerSize.width,
                scaledImageHeight: geometry.scaledImageHeight
            )
        )
    }
}

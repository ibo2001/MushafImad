//
//  MushafRenderConfiguration.swift
//  MushafImad
//

import SwiftUI

/// Configuration entry point that lets host applications choose how Mushaf
/// pages are drawn, following the same override pattern as
/// `MushafAssetConfiguration`.
///
/// This only governs pages rendered by `QuranPageView` (`DisplayMode.image`
/// in `MushafView`). `DisplayMode.text` renders through an entirely separate
/// text view and is unaffected by this configuration.
public struct MushafRenderConfiguration {
    public var renderSource: any MushafRenderSource

    public init(renderSource: any MushafRenderSource = LineImageRenderSource()) {
        self.renderSource = renderSource
    }
}

/// Runtime access to the active render source, honoring any override supplied by the host app.
@MainActor
public enum MushafRendering {
    /// Active configuration. Update this at launch or inside previews to override the default.
    public static var configuration = MushafRenderConfiguration()

    /// Reset to the default configuration (useful for examples and tests).
    public static func reset() {
        configuration = MushafRenderConfiguration()
    }
}

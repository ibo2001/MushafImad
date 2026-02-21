//
//  MushafAssetConfiguration.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 12/11/2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Configuration entry point that lets host applications override built-in colors and images.
public struct MushafAssetConfiguration {
    public var colorBundle: Bundle?
    public var imageBundle: Bundle?
    public var colorProvider: ((String) -> Color?)?
    public var imageProvider: ((String) -> Image?)?
    /// Additional font file URLs to register alongside the bundled Quran fonts.
    /// Pass URLs to `.ttf` or `.otf` files in your host app bundle.
    public var additionalFontURLs: [URL]

    public init(
        colorBundle: Bundle? = nil,
        imageBundle: Bundle? = nil,
        colorProvider: ((String) -> Color?)? = nil,
        imageProvider: ((String) -> Image?)? = nil,
        additionalFontURLs: [URL] = []
    ) {
        self.colorBundle = colorBundle
        self.imageBundle = imageBundle
        self.colorProvider = colorProvider
        self.imageProvider = imageProvider
        self.additionalFontURLs = additionalFontURLs
    }
}

/// Runtime helpers that resolve colors and images, honoring any overrides supplied by the host app.
@MainActor
public enum MushafAssets {
    /// Active configuration. Update this at launch or inside previews to override defaults.
    public static var configuration = MushafAssetConfiguration()
    
    /// Reset to default configuration (useful for examples and tests).
    public static func reset() {
        configuration = MushafAssetConfiguration()
    }

    /// Registers bundled Quran fonts and any additional fonts supplied via ``MushafAssetConfiguration/additionalFontURLs``.
    ///
    /// Call this instead of `FontRegistrar.registerFontsIfNeeded()` when you want
    /// host-app fonts to be registered in the same pass.
    public static func registerFonts() {
        FontRegistrar.registerFontsIfNeeded(additionalURLs: configuration.additionalFontURLs)
    }

    /// Resolve a color asset using the override configuration or bundled default.
    public static func color(named name: String) -> Color {
        if let custom = configuration.colorProvider?(name) {
            return custom
        }
        
        if let bundle = configuration.colorBundle, bundle.hasColor(named: name) {
            return Color(name, bundle: bundle)
        }
        
        return Color(name, bundle: .mushafResources)
    }
    
    /// Resolve an image asset using the override configuration or bundled default.
    public static func image(named name: String) -> Image {
        if let custom = configuration.imageProvider?(name) {
            return custom
        }
        
        if let bundle = configuration.imageBundle, bundle.hasImage(named: name) {
            return Image(name, bundle: bundle)
        }
        
        return Image(name, bundle: .mushafResources)
    }
}

private extension Bundle {
    func hasColor(named name: String) -> Bool {
        #if canImport(UIKit)
        return UIColor(named: name, in: self, compatibleWith: nil) != nil
        #elseif canImport(AppKit)
        return NSColor(named: NSColor.Name(name), bundle: self) != nil
        #else
        return false
        #endif
    }
    
    func hasImage(named name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name, in: self, compatibleWith: nil) != nil
        #elseif canImport(AppKit)
        // On macOS, check if image exists in the bundle
        // Check for file-based images
        let imageExtensions = ["png", "jpg", "jpeg", "tiff", "tif", "pdf"]
        for ext in imageExtensions {
            if self.url(forResource: name, withExtension: ext) != nil {
                return true
            }
        }
        // For asset catalogs, we can't easily check without loading
        // SwiftUI's Image(name, bundle:) will handle asset catalog loading
        // So we'll be optimistic and return true if the bundle is valid
        // The actual existence will be determined when Image tries to load it
        return self.bundleIdentifier != nil
        #else
        return false
        #endif
    }
}



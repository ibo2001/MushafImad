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
    
    public init(
        colorBundle: Bundle? = nil,
        imageBundle: Bundle? = nil,
        colorProvider: ((String) -> Color?)? = nil,
        imageProvider: ((String) -> Image?)? = nil
    ) {
        self.colorBundle = colorBundle
        self.imageBundle = imageBundle
        self.colorProvider = colorProvider
        self.imageProvider = imageProvider
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
        return NSImage(named: NSImage.Name(name), in: self, for: nil) != nil
        #else
        return false
        #endif
    }
}



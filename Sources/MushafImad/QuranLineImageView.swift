//
//  QuranLineImageView.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Displays a single Quran line image loaded directly from the bundle.
public struct QuranLineImageView: View {
    public let page: Int
    public let line: Int

    /// Desired layout
    public let imageAspect: CGFloat
    public let containerWidth: CGFloat
    public let scaledImageHeight: CGFloat

    #if canImport(UIKit)
    @State private var uiImage: UIImage? = nil
    #elseif canImport(AppKit)
    @State private var nsImage: NSImage? = nil
    #endif

    public init(
        page: Int,
        line: Int,
        imageAspect: CGFloat,
        containerWidth: CGFloat,
        scaledImageHeight: CGFloat
    ) {
        self.page = page
        self.line = line
        self.imageAspect = imageAspect
        self.containerWidth = containerWidth
        self.scaledImageHeight = scaledImageHeight
    }

    public var body: some View {
        ZStack {
            #if canImport(UIKit)
            if let uiImage {
                Image(uiImage: uiImage)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(imageAspect, contentMode: .fit)
                    .frame(width: containerWidth, height: scaledImageHeight)
                    .clipped()
                    .allowsHitTesting(false)
            } else {
                placeholder
            }
            #elseif canImport(AppKit)
            if let nsImage {
                Image(nsImage: nsImage)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(imageAspect, contentMode: .fit)
                    .frame(width: containerWidth, height: scaledImageHeight)
                    .clipped()
                    .allowsHitTesting(false)
            } else {
                placeholder
            }
            #endif
        }
        .onAppear {
            loadImage()
        }
    }
    
    private var placeholder: some View {
        Rectangle()
            .fill(.secondary.opacity(0.05))
            .frame(width: containerWidth, height: scaledImageHeight)
            .allowsHitTesting(false)
    }

    /// Load image directly from bundle - fast and simple
    private func loadImage() {
        guard let url = Bundle.module.url(
            forResource: "\(line)",
            withExtension: "png",
            subdirectory: "quran-images/\(page)"
        ) else {
            return
        }
        
        #if canImport(UIKit)
        uiImage = UIImage(contentsOfFile: url.path)
        #elseif canImport(AppKit)
        nsImage = NSImage(contentsOf: url)
        #endif
    }
}

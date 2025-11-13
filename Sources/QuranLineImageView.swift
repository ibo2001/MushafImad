//
//  QuranLineImageView.swift
//  MushafImad
//
//  Created by Assistant on 30/10/2025.
//

import SwiftUI

/// Displays a single Quran line image loaded from disk, downloading on demand.
public struct QuranLineImageView: View {
    public let page: Int
    public let line: Int

    /// Desired layout
    public let imageAspect: CGFloat
    public let containerWidth: CGFloat
    public let scaledImageHeight: CGFloat

    @State private var uiImage: UIImage? = nil

    @StateObject private var providerRef = QuranImageProvider.shared

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
            if let uiImage {
                Image(uiImage: uiImage)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(imageAspect, contentMode: .fit)
                    .frame(width: containerWidth, height: scaledImageHeight)
                    .clipped()
                    .allowsHitTesting(false)
                
            } else {
                // Minimal placeholder - images should already be prefetched
                Rectangle()
                    .fill(.secondary.opacity(0.05))
                    .frame(width: containerWidth, height: scaledImageHeight)
                    .allowsHitTesting(false)
            }
        }
        .task(id: "\(page)-\(line)") {
            await load()
        }
    }

    @MainActor
    private func load() async {
        // Try to get from cache first (should hit most of the time due to prefetching)
        if let img = await providerRef.image(page: page, line: line) {
            uiImage = img
            return
        }
        // If not cached, ensure it's available and try again
        await providerRef.ensureAvailable(page: page, line: line)
        uiImage = await providerRef.image(page: page, line: line)
    }
}



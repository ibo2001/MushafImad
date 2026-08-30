#!/usr/bin/env swift
//
//  compose_page_images.swift
//  MushafImad – Build-time tooling
//
//  Composites 604 full-page Mushaf images by vertically stitching
//  15 line PNGs (1440×232 each) into a single 1440×3480 RGBA PNG.
//
//  Usage:
//      swift compose_page_images.swift
//
//  The script expects to be run from the repository root, or you can
//  pass the repo root as the first argument:
//      swift compose_page_images.swift /path/to/MushafImad
//
//  Output is written to Sources/MushafImad/quran-page-images/<page>.png
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Configuration

let lineWidth  = 1440
let lineHeight = 232
let linesPerPage = 15
let pageWidth  = lineWidth
let pageHeight = lineHeight * linesPerPage  // 3480
let totalPages = 604

// MARK: - Resolve paths

let repoRoot: String = {
    if CommandLine.arguments.count > 1 {
        return CommandLine.arguments[1]
    }
    return FileManager.default.currentDirectoryPath
}()

let lineImagesDir = (repoRoot as NSString).appendingPathComponent("Sources/MushafImad/quran-images")
let pageImagesDir = (repoRoot as NSString).appendingPathComponent("Sources/MushafImad/quran-page-images")

// MARK: - Helpers

func fail(_ message: String) -> Never {
    fputs("❌ \(message)\n", stderr)
    exit(1)
}

func loadCGImage(at path: String) -> CGImage {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fail("Failed to load image: \(path)")
    }
    return image
}

func savePNG(image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    // Deterministic PNG: no auxiliary metadata, no timestamps
    let options: [CFString: Any] = [
        kCGImagePropertyHasAlpha: true
    ]
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL,
        "public.png" as CFString,
        1,
        nil
    ) else {
        fail("Failed to create image destination: \(path)")
    }
    CGImageDestinationAddImage(dest, image, options as CFDictionary)
    guard CGImageDestinationFinalize(dest) else {
        fail("Failed to write PNG: \(path)")
    }
}

func fileSize(at path: String) -> UInt64 {
    let attrs = try? FileManager.default.attributesOfItem(atPath: path)
    return attrs?[.size] as? UInt64 ?? 0
}

// MARK: - Validation

// Verify the line-images directory exists
guard FileManager.default.fileExists(atPath: lineImagesDir) else {
    fail("Line images directory not found: \(lineImagesDir)\nRun this script from the repository root.")
}

// MARK: - Create output directory

try? FileManager.default.createDirectory(atPath: pageImagesDir, withIntermediateDirectories: true)

// MARK: - Compose pages

print("🖼  Composing \(totalPages) page images from line images...")
print("   Input:  \(lineImagesDir)")
print("   Output: \(pageImagesDir)")
print("   Page dimensions: \(pageWidth)×\(pageHeight) (15 lines × 232px, zero spacing)")
print("")

let startTime = CFAbsoluteTimeGetCurrent()
var totalOutputBytes: UInt64 = 0
var errors: [String] = []

for page in 1...totalPages {
    // Create an RGBA context with transparent background
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: pageWidth,
        height: pageHeight,
        bitsPerComponent: 8,
        bytesPerRow: pageWidth * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        errors.append("Page \(page): Failed to create CGContext")
        continue
    }

    // Clear to fully transparent
    ctx.clear(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

    // Draw each line — CoreGraphics origin is bottom-left,
    // so line 1 (top of page) goes at y = (14) * 232
    for lineIndex in 0..<linesPerPage {
        let lineNumber = lineIndex + 1
        let linePath = (lineImagesDir as NSString)
            .appendingPathComponent("\(page)")
            .appending("/\(lineNumber).png")

        guard FileManager.default.fileExists(atPath: linePath) else {
            errors.append("Page \(page), line \(lineNumber): File not found at \(linePath)")
            continue
        }

        let lineImage = loadCGImage(at: linePath)

        // Validate dimensions
        guard lineImage.width == lineWidth, lineImage.height == lineHeight else {
            errors.append("Page \(page), line \(lineNumber): Unexpected size \(lineImage.width)×\(lineImage.height)")
            continue
        }

        let yOffset = (linesPerPage - 1 - lineIndex) * lineHeight
        ctx.draw(lineImage, in: CGRect(x: 0, y: yOffset, width: lineWidth, height: lineHeight))
    }

    // Extract composed image
    guard let composedImage = ctx.makeImage() else {
        errors.append("Page \(page): Failed to create composed image")
        continue
    }

    // Verify alpha is preserved
    let alphaInfo = composedImage.alphaInfo
    if alphaInfo == .none || alphaInfo == .noneSkipFirst || alphaInfo == .noneSkipLast {
        errors.append("Page \(page): ⚠️  Alpha channel missing in composed image (alphaInfo=\(alphaInfo.rawValue))")
    }

    // Verify dimensions
    guard composedImage.width == pageWidth, composedImage.height == pageHeight else {
        errors.append("Page \(page): Wrong output size \(composedImage.width)×\(composedImage.height)")
        continue
    }

    // Save
    let outputPath = (pageImagesDir as NSString).appendingPathComponent("\(page).png")
    savePNG(image: composedImage, to: outputPath)
    totalOutputBytes += fileSize(at: outputPath)

    // Progress indicator
    if page % 50 == 0 || page == totalPages {
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let pct = Double(page) / Double(totalPages) * 100
        print("   [\(String(format: "%3.0f", pct))%] Page \(page)/\(totalPages) — \(String(format: "%.1f", elapsed))s elapsed")
    }
}

let totalElapsed = CFAbsoluteTimeGetCurrent() - startTime

// MARK: - Size report

// Calculate total line-images size
var totalInputBytes: UInt64 = 0
for page in 1...totalPages {
    for line in 1...linesPerPage {
        let path = (lineImagesDir as NSString)
            .appendingPathComponent("\(page)")
            .appending("/\(line).png")
        totalInputBytes += fileSize(at: path)
    }
}

func formatBytes(_ bytes: UInt64) -> String {
    let mb = Double(bytes) / 1_048_576
    return String(format: "%.1f MB", mb)
}

print("")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  📊  SIZE REPORT")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  Line images (input):   \(formatBytes(totalInputBytes))  (\(totalPages * linesPerPage) files)")
print("  Page images (output):  \(formatBytes(totalOutputBytes))  (\(totalPages) files)")
let ratio = totalInputBytes > 0 ? Double(totalOutputBytes) / Double(totalInputBytes) * 100 : 0
let delta = Int64(totalOutputBytes) - Int64(totalInputBytes)
let deltaStr = delta >= 0 ? "+\(formatBytes(UInt64(delta)))" : "-\(formatBytes(UInt64(-delta)))"
print("  Ratio:                 \(String(format: "%.1f", ratio))%  (\(deltaStr))")
if Double(totalOutputBytes) >= Double(totalInputBytes) * 0.9 {
    print("")
    print("  ⚠️  Page images are NOT meaningfully smaller than line images.")
    print("     Consider noting this in the PR — payload savings is minimal.")
} else {
    print("")
    print("  ✅  Page images are smaller. Consolidation saves space.")
}
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("")
print("  ⏱   Completed in \(String(format: "%.1f", totalElapsed))s")

// MARK: - Error summary

if !errors.isEmpty {
    print("")
    print("⚠️  \(errors.count) warning(s):")
    for e in errors {
        print("   • \(e)")
    }
}

// MARK: - Verification: spot-check alpha on page 1

let verifyPath = (pageImagesDir as NSString).appendingPathComponent("1.png")
if FileManager.default.fileExists(atPath: verifyPath) {
    let verifyImage = loadCGImage(at: verifyPath)
    let hasAlpha = verifyImage.alphaInfo != .none
        && verifyImage.alphaInfo != .noneSkipFirst
        && verifyImage.alphaInfo != .noneSkipLast
    print("")
    if hasAlpha {
        print("✅ Alpha verification passed (page 1): alphaInfo=\(verifyImage.alphaInfo.rawValue)")
    } else {
        print("❌ Alpha verification FAILED (page 1): alphaInfo=\(verifyImage.alphaInfo.rawValue)")
        print("   Theme tinting will break — page images must preserve transparency.")
    }
    print("✅ Dimensions: \(verifyImage.width)×\(verifyImage.height)")
}

if errors.isEmpty {
    print("")
    print("✨ All \(totalPages) page images composed successfully!")
} else {
    exit(1)
}

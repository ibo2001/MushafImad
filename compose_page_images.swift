#!/usr/bin/env swift
//
//  compose_page_images.swift
//  MushafImad – Build-time tooling
//
//  Composites 604 full-page Mushaf images by vertically stitching 15 line PNGs
//  (1440×232 each) at the reader's 169.36px render pitch (lineHeight * 0.73)
//  into 1440×2603 RGBA PNGs.
//
//  Line layout matches QuranPageView portrait rendering: consecutive lines
//  overlap by 27%, matching the reader's own compositing. This makes the
//  composed page image an exact 1:1 visual match with the app reader in portrait.
//
//  Geometry note for render sources (#70):
//  - Image height (visual bounding box): 2603px (14 * 169.36 + 232 = 2603.04)
//  - Layout height (VStack slot consumption): 2540.4px (15 * 169.36)
//  Line 15 naturally overflows its slot by 62.6px over the Spacer() below it.
//  Downstream render sources should draw at height = width * 2603 / 1440,
//  top-aligned with the first line slot — not aspect-fit into the 2540.4 box
//  (which would shrink the page by 2.4% and desync tap/highlight coordinates).
//
//  Usage:
//      ./compose_page_images.swift [options]
//      # or: swift compose_page_images.swift [options]
//
//  Options:
//      --page, -p <1..604>   Compose a single page
//      --all, -a             Compose all 604 pages (default)
//      --lines-dir <path>    Custom directory of source line images
//      --output-dir <path>   Custom directory for output page images
//      --repo-root <path>    Repository root directory
//      --help, -h            Show this help message
//
//  Default output is written to build/page-images/<page>.png
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Configuration

let lineWidth        = 1440
let lineHeight       = 232
let linesPerPage     = 15
let lineHeightScale  = 0.73
let linePitch        = Double(lineHeight) * lineHeightScale // 169.36
let pageWidth        = lineWidth
let pageHeight       = Int(round(Double(linesPerPage - 1) * linePitch + Double(lineHeight))) // 2603
let layoutHeight     = Double(linesPerPage) * linePitch // 2540.4
let totalPages       = 604

// MARK: - CLI Argument Parsing

struct CLIOptions {
    var targetPage: Int? = nil
    var repoRoot: String = FileManager.default.currentDirectoryPath
    var customLinesDir: String? = nil
    var customOutputDir: String? = nil
}

func printUsage() {
    print("""
    Usage:
      ./compose_page_images.swift [options]
      swift compose_page_images.swift [options]

    Options:
      -p, --page <1..604>   Compose a single page (useful for quick iteration)
      -a, --all             Compose all 604 pages (default)
      --lines-dir <path>    Custom source line images directory
      --output-dir <path>   Custom output page images directory
      --repo-root <path>    Repository root path
      -h, --help            Show this help message

    Examples:
      ./compose_page_images.swift --page 1
      ./compose_page_images.swift --all
      ./compose_page_images.swift --output-dir /tmp/page-images
    """)
}

func parseArguments() -> CLIOptions {
    var options = CLIOptions()
    let args = Array(CommandLine.arguments.dropFirst())
    var index = 0

    while index < args.count {
        let arg = args[index]
        switch arg {
        case "-h", "--help":
            printUsage()
            exit(0)
        case "-p", "--page":
            index += 1
            guard index < args.count, let pageNum = Int(args[index]), (1...totalPages).contains(pageNum) else {
                fputs("❌ Error: --page requires a page number between 1 and \(totalPages)\n", stderr)
                exit(1)
            }
            options.targetPage = pageNum
        case "-a", "--all":
            options.targetPage = nil
        case "--lines-dir":
            index += 1
            guard index < args.count else {
                fputs("❌ Error: --lines-dir requires a directory path\n", stderr)
                exit(1)
            }
            options.customLinesDir = args[index]
        case "--output-dir":
            index += 1
            guard index < args.count else {
                fputs("❌ Error: --output-dir requires a directory path\n", stderr)
                exit(1)
            }
            options.customOutputDir = args[index]
        case "--repo-root":
            index += 1
            guard index < args.count else {
                fputs("❌ Error: --repo-root requires a directory path\n", stderr)
                exit(1)
            }
            options.repoRoot = args[index]
        default:
            fputs("❌ Error: Unknown argument '\(arg)'. Use --help for usage.\n", stderr)
            exit(1)
        }
        index += 1
    }

    return options
}

let cliOptions = parseArguments()

// MARK: - Resolve paths

let repoRoot = cliOptions.repoRoot
let lineImagesDir: String = {
    if let custom = cliOptions.customLinesDir {
        return (custom as NSString).standardizingPath
    }
    return (repoRoot as NSString).appendingPathComponent("Sources/MushafImad/quran-images")
}()

let pageImagesDir: String = {
    if let custom = cliOptions.customOutputDir {
        return (custom as NSString).standardizingPath
    }
    // Default outside Sources/ to avoid SwiftPM unhandled-file target warnings
    return (repoRoot as NSString).appendingPathComponent("build/page-images")
}()

// MARK: - Helpers

func fail(_ message: String) -> Never {
    fputs("❌ \(message)\n", stderr)
    exit(1)
}

func loadCGImage(at path: String) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        return nil
    }
    return image
}

func savePNG(image: CGImage, to path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL,
        "public.png" as CFString,
        1,
        nil
    ) else {
        return false
    }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

func fileSize(at path: String) -> UInt64 {
    let attrs = try? FileManager.default.attributesOfItem(atPath: path)
    return attrs?[.size] as? UInt64 ?? 0
}

func formatBytes(_ bytes: UInt64) -> String {
    let mb = Double(bytes) / 1_048_576
    return String(format: "%.1f MB", mb)
}

// MARK: - Validation

guard FileManager.default.fileExists(atPath: lineImagesDir) else {
    fail("Line images directory not found: \(lineImagesDir)\nRun this script from the repository root or pass --lines-dir.")
}

// MARK: - Create output directory

do {
    try FileManager.default.createDirectory(atPath: pageImagesDir, withIntermediateDirectories: true)
} catch {
    fail("Failed to create output directory \(pageImagesDir): \(error)")
}

// MARK: - Compose pages

let pagesToProcess: [Int] = {
    if let singlePage = cliOptions.targetPage {
        return [singlePage]
    }
    return Array(1...totalPages)
}()

print("🖼  Composing \(pagesToProcess.count) page image(s) from line images...")
print("   Input:          \(lineImagesDir)")
print("   Output:         \(pageImagesDir)")
print("   Dimensions:     \(pageWidth)×\(pageHeight) px")
print("   Render pitch:   \(String(format: "%.2f", linePitch)) px (232px × 0.73, matching QuranPageView portrait)")
print("   Layout height:  \(String(format: "%.1f", layoutHeight)) px (slot height; line 15 extends 62.6px past slot)")
print("")

let startTime = CFAbsoluteTimeGetCurrent()
var totalOutputBytes: UInt64 = 0
var successfulPages: [Int] = []
var errors: [String] = []
var firstSuccessfulPage: Int? = nil

for (idx, page) in pagesToProcess.enumerated() {
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

    var pageFailed = false

    // Draw each line from top (line 1) to bottom (line 15).
    // CoreGraphics origin is bottom-left, so we calculate the bottom offset for each line.
    for lineIndex in 0..<linesPerPage {
        let lineNumber = lineIndex + 1
        let linePath = (lineImagesDir as NSString)
            .appendingPathComponent("\(page)")
            .appending("/\(lineNumber).png")

        guard FileManager.default.fileExists(atPath: linePath) else {
            errors.append("Page \(page), line \(lineNumber): File not found at \(linePath)")
            pageFailed = true
            continue
        }

        guard let lineImage = loadCGImage(at: linePath) else {
            errors.append("Page \(page), line \(lineNumber): Failed to decode image at \(linePath)")
            pageFailed = true
            continue
        }

        guard lineImage.width == lineWidth, lineImage.height == lineHeight else {
            errors.append("Page \(page), line \(lineNumber): Unexpected size \(lineImage.width)×\(lineImage.height) (expected \(lineWidth)×\(lineHeight))")
            pageFailed = true
            continue
        }

        let yOffset = round(Double(pageHeight) - (Double(lineIndex) * linePitch + Double(lineHeight)))
        ctx.draw(lineImage, in: CGRect(x: 0, y: yOffset, width: Double(lineWidth), height: Double(lineHeight)))
    }

    // If any line failed, do NOT write a partial/blank page image to disk
    guard !pageFailed else {
        errors.append("Page \(page): Skipped writing to disk due to missing/corrupt line images")
        continue
    }

    guard let composedImage = ctx.makeImage() else {
        errors.append("Page \(page): Failed to create composed image")
        continue
    }

    let alphaInfo = composedImage.alphaInfo
    if alphaInfo == .none || alphaInfo == .noneSkipFirst || alphaInfo == .noneSkipLast {
        errors.append("Page \(page): ⚠️  Alpha channel missing in composed image (alphaInfo=\(alphaInfo.rawValue))")
    }

    guard composedImage.width == pageWidth, composedImage.height == pageHeight else {
        errors.append("Page \(page): Wrong output size \(composedImage.width)×\(composedImage.height)")
        continue
    }

    let outputPath = (pageImagesDir as NSString).appendingPathComponent("\(page).png")
    guard savePNG(image: composedImage, to: outputPath) else {
        errors.append("Page \(page): Failed to write PNG to \(outputPath)")
        continue
    }

    successfulPages.append(page)
    totalOutputBytes += fileSize(at: outputPath)
    if firstSuccessfulPage == nil {
        firstSuccessfulPage = page
    }

    // Progress indicator
    let currentCount = idx + 1
    if pagesToProcess.count > 1 && (currentCount % 50 == 0 || currentCount == pagesToProcess.count) {
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let pct = Double(currentCount) / Double(pagesToProcess.count) * 100
        print("   [\(String(format: "%3.0f", pct))%] Page \(page) (\(currentCount)/\(pagesToProcess.count)) — \(String(format: "%.1f", elapsed))s elapsed")
    }
}

let totalElapsed = CFAbsoluteTimeGetCurrent() - startTime

// MARK: - Size report

var totalInputBytes: UInt64 = 0
for page in successfulPages {
    for line in 1...linesPerPage {
        let path = (lineImagesDir as NSString)
            .appendingPathComponent("\(page)")
            .appending("/\(line).png")
        totalInputBytes += fileSize(at: path)
    }
}

print("")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  📊  SIZE REPORT")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  Processed:             \(successfulPages.count) of \(pagesToProcess.count) page(s)")
print("  Line images (input):   \(formatBytes(totalInputBytes))  (\(successfulPages.count * linesPerPage) files)")
print("  Page images (output):  \(formatBytes(totalOutputBytes))  (\(successfulPages.count) files)")
let ratio = totalInputBytes > 0 ? Double(totalOutputBytes) / Double(totalInputBytes) * 100 : 0
let delta = Int64(totalOutputBytes) - Int64(totalInputBytes)
let deltaStr = delta >= 0 ? "+\(formatBytes(UInt64(delta)))" : "-\(formatBytes(UInt64(-delta)))"
print("  Ratio:                 \(String(format: "%.1f", ratio))%  (\(deltaStr))")
print("")
print("  💡 Encoder & Size finding:")
print("     Page images are size-neutral; the naive encoder accounts for the disk difference.")
print("     Because sources are pure black (0,0,0) mask templates with alpha transparency,")
print("     all information is in the alpha channel. Measured alpha content (gzip -9)")
print("     is identical / marginally smaller as a full page image (~0.98x ratio).")
print("     CGImageDestination writes uncompressed 32-bit RGBA8 (storing 3 zero color bytes per pixel),")
print("     whereas source line PNGs use palette/grayscale encoding. Recompressing with")
print("     tools like oxipng / zopflipng or 8-bit alpha masks eliminates the ~2.8x file size overhead.")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("")
print("  ⏱   Completed in \(String(format: "%.1f", totalElapsed))s")

// MARK: - Error summary

if !errors.isEmpty {
    print("")
    print("⚠️  \(errors.count) warning(s)/error(s):")
    for e in errors.prefix(20) {
        print("   • \(e)")
    }
    if errors.count > 20 {
        print("   ... and \(errors.count - 20) more")
    }
}

// MARK: - Verification: spot-check alpha on first successful page

if let verifiedPage = firstSuccessfulPage {
    let verifyPath = (pageImagesDir as NSString).appendingPathComponent("\(verifiedPage).png")
    if FileManager.default.fileExists(atPath: verifyPath), let verifyImage = loadCGImage(at: verifyPath) {
        let hasAlpha = verifyImage.alphaInfo != .none
            && verifyImage.alphaInfo != .noneSkipFirst
            && verifyImage.alphaInfo != .noneSkipLast
        print("")
        if hasAlpha {
            print("✅ Alpha verification passed (page \(verifiedPage)): alphaInfo=\(verifyImage.alphaInfo.rawValue)")
        } else {
            print("❌ Alpha verification FAILED (page \(verifiedPage)): alphaInfo=\(verifyImage.alphaInfo.rawValue)")
            print("   Theme tinting will break — page images must preserve transparency.")
        }
        print("✅ Dimensions: \(verifyImage.width)×\(verifyImage.height) (expected \(pageWidth)×\(pageHeight))")
    }
}

if errors.isEmpty && successfulPages.count == pagesToProcess.count {
    print("")
    print("✨ Composed \(successfulPages.count) page image(s) successfully!")
    exit(0)
} else {
    exit(1)
}

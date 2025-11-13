//
//  QuranImageFileStore.swift
//  MushafImad
//
//  Created by Ibrahim Qraiqe on 30/10/2025.
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIImage = NSImage

extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
#endif

/// Thread-safe file store handling on-disk Quran line images.
/// Folder structure: Documents/quran-images/{page}/{line}.png
public actor QuranImageFileStore {
    public static let shared = QuranImageFileStore()

    private let fileManager: FileManager
    private let imagesRootFolderName = "quran-images"

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Paths

    private func documentsDirectory() throws -> URL {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "QuranImageFileStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to locate Documents directory"])
        }
        return url
    }

    private func rootDirectoryURL() throws -> URL {
        return try documentsDirectory().appendingPathComponent(imagesRootFolderName, isDirectory: true)
    }

    public func fileURL(forPage page: Int, line: Int) throws -> URL {
        try ensurePageDirectoryExists(page: page)
        let pageDir = try rootDirectoryURL().appendingPathComponent(String(page), isDirectory: true)
        return pageDir.appendingPathComponent("\(line).png", isDirectory: false)
    }

    // MARK: - Ensure Directories

    @discardableResult
    public func ensureRootDirectoryExists() throws -> URL {
        let root = try rootDirectoryURL()
        if !fileManager.fileExists(atPath: root.path) {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    @discardableResult
    public func ensurePageDirectoryExists(page: Int) throws -> URL {
        try ensureRootDirectoryExists()
        let pageDir = try rootDirectoryURL().appendingPathComponent(String(page), isDirectory: true)
        if !fileManager.fileExists(atPath: pageDir.path) {
            try fileManager.createDirectory(at: pageDir, withIntermediateDirectories: true)
        }
        return pageDir
    }

    // MARK: - Existence

    public func exists(page: Int, line: Int) -> Bool {
        do {
            let url = try fileURL(forPage: page, line: line)
            return fileManager.fileExists(atPath: url.path)
        } catch {
            return false
        }
    }

    // MARK: - Read

    public func readImage(page: Int, line: Int) -> UIImage? {
        do {
            let url = try fileURL(forPage: page, line: line)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return UIImage(contentsOfFile: url.path)
        } catch {
            return nil
        }
    }

    // MARK: - Write (Atomic)

    /// Writes data to a temporary file then atomically moves it into place as {page}/{line}.png
    public func writeAtomically(data: Data, page: Int, line: Int) throws {
        try ensurePageDirectoryExists(page: page)
        let destination = try fileURL(forPage: page, line: line)

        // Create a temp file in the same directory to allow atomic move
        let tempURL = destination.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            // Remove existing file if present
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: tempURL, to: destination)
        } catch {
            // Best-effort cleanup
            try? fileManager.removeItem(at: tempURL)
            throw error
        }
    }

    // MARK: - Remove

    public func remove(page: Int, line: Int) {
        do {
            let url = try fileURL(forPage: page, line: line)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        } catch {
            // Ignore
        }
    }

    public func removePageFolder(page: Int) {
        do {
            let pageDir = try rootDirectoryURL().appendingPathComponent(String(page), isDirectory: true)
            if fileManager.fileExists(atPath: pageDir.path) {
                try fileManager.removeItem(at: pageDir)
            }
        } catch {
            // Ignore
        }
    }
}



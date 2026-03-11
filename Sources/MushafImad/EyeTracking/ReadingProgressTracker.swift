//
//  ReadingProgressTracker.swift
//  MushafImad
//
//  Created by Tamer on 11/03/2026.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
public final class ReadingProgressTracker: ObservableObject {
    @Published public private(set) var currentVerse: GazeToVerseResolver.ResolvedVerse?
    @Published public private(set) var isOnLastLine = false

    private let resolver = GazeToVerseResolver()
    private var lastSavedVerseID: Int?
    private var lastSaveTime: Date = .distantPast
    private let totalLines = 15
    private let saveInterval: TimeInterval = 5.0

    public init() {}

    public func update(
        gazePoint: GazePoint,
        page: Int,
        mushafType: MushafType = .hafs1441
    ) {
        let resolved = resolver.resolve(
            gazePoint: gazePoint,
            page: page,
            mushafType: mushafType
        )

        if let resolved, resolved.confidence > 0.3 {
            currentVerse = resolved
        }

        isOnLastLine = gazePoint.line >= totalLines - 1
    }

    public func saveProgressIfNeeded(modelContext: ModelContext) {
        guard let verse = currentVerse else { return }
        guard verse.verseID != lastSavedVerseID else { return }

        let now = Date.now
        guard now.timeIntervalSince(lastSaveTime) >= saveInterval else { return }

        let reading = RecentReading(
            surahNumber: verse.chapterNumber,
            verseID: verse.verseID,
            verseNumber: verse.verseNumber
        )
        modelContext.insert(reading)

        lastSavedVerseID = verse.verseID
        lastSaveTime = now
    }

    public func updateKhatmaProgress(
        page: Int,
        modelContext: ModelContext
    ) {
        let descriptor = FetchDescriptor<MyKhatma>(
            sortBy: [SortDescriptor(\.lastUpdatedAt, order: .reverse)]
        )
        guard let khatmas = try? modelContext.fetch(descriptor),
              let active = khatmas.first else { return }

        let currentLast = active.lastReadPage ?? 0
        guard page > currentLast else { return }

        active.lastReadPage = page
        active.lastUpdatedAt = Date.now
    }

    public func forceSave(modelContext: ModelContext) {
        guard let verse = currentVerse else { return }
        guard verse.verseID != lastSavedVerseID else { return }

        let reading = RecentReading(
            surahNumber: verse.chapterNumber,
            verseID: verse.verseID,
            verseNumber: verse.verseNumber
        )
        modelContext.insert(reading)

        lastSavedVerseID = verse.verseID
        lastSaveTime = .now
    }

    public func reset() {
        currentVerse = nil
        isOnLastLine = false
        lastSavedVerseID = nil
        lastSaveTime = .distantPast
    }
}

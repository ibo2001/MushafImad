//
//  MyReadsModels.swift
//  MushafImad
//
//  Created by Assistant on 10/11/2025.
//

import Foundation
import SwiftData

/// Describes the predefined durations that a khatma can follow.
/// - Important: For the `.custom` case a `customDurationDays` value must be supplied.
public enum KhatmaDuration: String, Codable, CaseIterable, Identifiable {
    case sevenDays
    case tenDays
    case fifteenDays
    case month
    case custom
    
    public var id: String { rawValue }
    
    /// Localized, user-facing title.
    public var title: String {
        switch self {
        case .sevenDays:
            return String(localized: "7 days")
        case .tenDays:
            return String(localized: "10 days")
        case .fifteenDays:
            return String(localized: "15 days")
        case .month:
            return String(localized: "1 month")
        case .custom:
            return String(localized: "Custom")
        }
    }
    
    /// Number of days associated with each duration.
    /// - Note: `.custom` returns `nil` because the value is provided externally.
    public var defaultDays: Int? {
        switch self {
        case .sevenDays:
            return 7
        case .tenDays:
            return 10
        case .fifteenDays:
            return 15
        case .month:
            return 30
        case .custom:
            return nil
        }
    }
}

/// Represents a single khatma plan with progress tracking stored via SwiftData.
@Model
public final class MyKhatma {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var duration: KhatmaDuration
    public var customDurationDays: Int?
    public var createdAt: Date
    public var lastReadPage: Int?
    public var lastUpdatedAt: Date?
    
    /// Default total pages for the Mushaf. Stored to allow future customisations.
    public var totalPages: Int
    
    public init(
        id: UUID = UUID(),
        title: String,
        duration: KhatmaDuration,
        customDurationDays: Int? = nil,
        createdAt: Date = .now,
        lastReadPage: Int? = nil,
        lastUpdatedAt: Date? = nil,
        totalPages: Int = 604
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.customDurationDays = customDurationDays
        self.createdAt = createdAt
        self.lastReadPage = lastReadPage
        self.lastUpdatedAt = lastUpdatedAt
        self.totalPages = totalPages
    }
    
    /// Effective duration in days, falling back to the duration defaults.
    public var durationInDays: Int {
        if let customDays = customDurationDays, customDays > 0 {
            return customDays
        }
        return duration.defaultDays ?? max(1, totalPages)
    }
    
    /// Daily pages the user needs to read to complete the khatma in the selected duration.
    public var dailyPages: Double {
        guard durationInDays > 0 else { return Double(totalPages) }
        return Double(totalPages) / Double(durationInDays)
    }
    
    /// Rounded number of daily pages that should be displayed to the user.
    public var roundedDailyPages: Int {
        Int(dailyPages.rounded(.up))
    }
    
    /// Percentage-based progress based on the last read page.
    public var progressPercentage: Double {
        guard let lastReadPage else { return 0 }
        guard totalPages > 0 else { return 0 }
        return min(1.0, max(0.0, Double(lastReadPage) / Double(totalPages)))
    }
    
    /// Last read page number formatted for user display.
    public var lastReadPageLabel: String? {
        guard let lastReadPage else { return nil }
        return String(localized: "Page \(lastReadPage)")
    }
}

/// Represents a surah that the user tagged for frequent re-reading.
@Model
public final class SurahReRead {
    @Attribute(.unique) public var id: UUID
    public var surahNumber: Int
    public var note: String?
    public var createdAt: Date
    public var lastReviewedAt: Date
    
    public init(
        id: UUID = UUID(),
        surahNumber: Int,
        note: String? = nil,
        createdAt: Date = .now,
        lastReviewedAt: Date = .now
    ) {
        self.id = id
        self.surahNumber = surahNumber
        self.note = note
        self.createdAt = createdAt
        self.lastReviewedAt = lastReviewedAt
    }
}

/// Holds quick access to the most recent readings performed by the user.
@Model
public final class RecentReading {
    @Attribute(.unique) public var id: UUID
    public var surahNumber: Int
    public var verseID: Int
    public var verseNumber: Int
    public var readAt: Date
    
    public init(
        id: UUID = UUID(),
        surahNumber: Int,
        verseID: Int,
        verseNumber: Int,
        readAt: Date = .now
    ) {
        self.id = id
        self.surahNumber = surahNumber
        self.verseID = verseID
        self.verseNumber = verseNumber
        self.readAt = readAt
    }
}


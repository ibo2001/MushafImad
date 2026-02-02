import Foundation
import SwiftUI
import Combine

/// Central registry that exposes available Quran reciters and persists the user's selection.
///
/// `ReciterService` manages the list of available reciters (readers of the Quran) and tracks
/// which reciter the user has selected. It loads reciter data from JSON files or falls back
/// to embedded data if needed.
///
/// ## Usage
///
/// Access the shared instance to get the list of reciters or the currently selected reciter:
///
/// ```swift
/// let service = ReciterService.shared
/// print(service.availableReciters.count) // e.g., 18
/// print(service.selectedReciter?.displayName) // e.g., "Mishary Al-Afasy"
/// ```
///
/// ## Topics
///
/// ### Getting Reciters
/// - ``availableReciters``
/// - ``selectedReciter``
/// - ``getReciterById(_:)``
///
/// ### Selection
/// - ``selectReciter(_:)``
///
/// ### Audio Playback
/// - ``getCurrentReciterBaseURL()``
@MainActor
public final class ReciterService: ObservableObject {
    /// The shared singleton instance of the reciter service.
    ///
    /// Use this property to access the reciter service throughout your app:
    /// ```swift
    /// let service = ReciterService.shared
    /// ```
    public static let shared = ReciterService()
    
    /// Lightweight reciter descriptor surfaced to the UI layer.
    ///
    /// Contains essential information about a Quran reciter including their name
    /// in Arabic and English, the recitation style (rewaya), and the URL where
    /// their audio files are hosted.
    public struct ReciterInfo: Identifiable, Equatable, Codable {
        /// Unique identifier for the reciter.
        ///
        /// This ID corresponds to the reciter's identifier in the audio database
        /// and is used to persist the user's selection.
        public let id: Int
        
        /// The reciter's name in Arabic script.
        ///
        /// Example: "مشاري العفاسي"
        public let nameArabic: String
        
        /// The reciter's name in English transliteration.
        ///
        /// Example: "Mishary Al-Afasy"
        public let nameEnglish: String
        
        /// The recitation style or transmission chain.
        ///
        /// Common values include "Hafs" (the most widespread), "Warsh", etc.
        /// Example: "Hafs A'n Assem"
        public let rewaya: String
        
        /// The base URL path where the reciter's MP3 files are hosted.
        ///
        /// This URL is used to construct the full audio file URLs for each chapter.
        public let folderURL: String
        
        /// Creates a new reciter info instance.
        ///
        /// - Parameters:
        ///   - id: Unique identifier for the reciter.
        ///   - nameArabic: The reciter's name in Arabic.
        ///   - nameEnglish: The reciter's name in English.
        ///   - rewaya: The recitation style (e.g., "Hafs").
        ///   - folderURL: Base URL for the reciter's audio files.
        public init(
            id: Int,
            nameArabic: String,
            nameEnglish: String,
            rewaya: String,
            folderURL: String
        ) {
            self.id = id
            self.nameArabic = nameArabic
            self.nameEnglish = nameEnglish
            self.rewaya = rewaya
            self.folderURL = folderURL
        }
        
        /// The localized display name based on the user's current locale.
        ///
        /// Returns the Arabic name if the device language is Arabic,
        /// otherwise returns the English name.
        ///
        /// ```swift
        /// // On Arabic device:
        /// reciter.displayName // "مشاري العفاسي"
        ///
        /// // On English device:
        /// reciter.displayName // "Mishary Al-Afasy"
        /// ```
        public var displayName: String {
            // Check current locale to determine which name to show
            let preferredLanguage: String
            if #available(macOS 13.0, iOS 16.0, *) {
                preferredLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            } else {
                preferredLanguage = Locale.current.languageCode ?? "en"
            }
            return preferredLanguage == "ar" ? nameArabic : nameEnglish
        }
        
        /// The base URL where MP3 audio files for this reciter are hosted.
        ///
        /// Returns `nil` if the `folderURL` string cannot be converted to a valid URL.
        ///
        /// Use this URL to construct full audio file paths:
        /// ```swift
        /// if let baseURL = reciter.audioBaseURL {
        ///     let chapterURL = baseURL.appendingPathComponent("001.mp3")
        /// }
        /// ```
        public var audioBaseURL: URL? {
            URL(string: folderURL)
        }
    }
    
    /// The list of all available reciters.
    ///
    /// This array is populated on initialization and sorted by reciter ID.
    /// It typically contains 18+ reciters with various recitation styles.
    ///
    /// Use this property to display a reciter selection UI:
    /// ```swift
    /// ForEach(reciterService.availableReciters) { reciter in
    ///     Text(reciter.displayName)
    /// }
    /// ```
    @Published public private(set) var availableReciters: [ReciterInfo] = []
    
    /// The currently selected reciter for audio playback.
    ///
    /// When changed, the selection is automatically persisted to `AppStorage`
    /// and restored on the next app launch.
    ///
    /// This value is `nil` only if no reciters are available (which should not
    /// happen under normal circumstances).
    @Published public var selectedReciter: ReciterInfo? {
        didSet {
            // Save to AppStorage when reciter changes
            if let reciter = selectedReciter {
                savedReciterId = reciter.id
            }
        }
    }
    
    /// Indicates whether the reciter data is currently being loaded.
    ///
    /// This is `true` during initialization and becomes `false` once the
    /// reciters are loaded from JSON or fallback data.
    @Published public private(set) var isLoading: Bool = true
    
    @AppStorage("selectedReciterId") private var savedReciterId: Int = 0
    
    private init() {
        // Load synchronously on main thread to ensure it's ready
        loadAvailableRecitersSync()
    }
    
    private func loadAvailableRecitersSync() {
        var reciters: [ReciterInfo] = []
        
        // List of available reciter IDs based on JSON files
        let reciterIds = [1, 5, 9, 10, 31, 32, 51, 53, 60, 62, 67, 74, 78, 106, 112, 118, 159, 256]
        
        // Try to load from JSON files first
        var loadedFromJSON = false
        for id in reciterIds {
            if let reciterTiming = AyahTimingService.shared.getReciter(id: id) {
                let info = ReciterInfo(
                    id: reciterTiming.id,
                    nameArabic: reciterTiming.name,
                    nameEnglish: reciterTiming.name_en,
                    rewaya: reciterTiming.rewaya,
                    folderURL: reciterTiming.folder_url
                )
                reciters.append(info)
                loadedFromJSON = true
            }
        }
        
        // If no reciters loaded from JSON, use the embedded data as fallback
        if !loadedFromJSON {
            AppLogger.shared.warn("ReciterService: No reciters loaded from JSON files, using embedded fallback data", category: .network)
            for reciterData in ReciterDataProvider.reciters {
                let info = ReciterInfo(
                    id: reciterData.id,
                    nameArabic: reciterData.nameArabic,
                    nameEnglish: reciterData.nameEnglish,
                    rewaya: reciterData.rewaya,
                    folderURL: reciterData.folderURL
                )
                reciters.append(info)
            }
        }
        
        // Sort by ID to maintain consistent order (first reciter will be ID 1)
        reciters.sort { $0.id < $1.id }
        
        self.availableReciters = reciters
        
        AppLogger.shared.info("ReciterService: Loaded \(reciters.count) reciters", category: .network)
        
        // Load saved reciter from AppStorage or use first available as default
        if savedReciterId > 0, let saved = reciters.first(where: { $0.id == savedReciterId }) {
            self.selectedReciter = saved
            AppLogger.shared.info("ReciterService: Selected saved reciter: \(saved.displayName) (ID: \(saved.id))", category: .network)
        } else if let firstReciter = reciters.first {
            // Set first reciter as default
            self.selectedReciter = firstReciter
            self.savedReciterId = firstReciter.id
            AppLogger.shared.info("ReciterService: Selected default reciter: \(firstReciter.displayName) (ID: \(firstReciter.id))", category: .network)
        }
        
        if let selectedReciter = self.selectedReciter {
            AppLogger.shared.info("ReciterService: Audio base URL: \(selectedReciter.folderURL)", category: .network)
        }
        
        self.isLoading = false
    }
    
    /// Updates the active reciter and persists the choice.
    ///
    /// Call this method when the user selects a different reciter from the UI.
    /// The selection is automatically saved and will be restored on the next app launch.
    ///
    /// - Parameter reciter: The reciter to select.
    ///
    /// ```swift
    /// if let newReciter = reciterService.availableReciters.first(where: { $0.nameEnglish == "Abdul Basit" }) {
    ///     reciterService.selectReciter(newReciter)
    /// }
    /// ```
    public func selectReciter(_ reciter: ReciterInfo) {
        selectedReciter = reciter
    }
    
    /// Fetches a reciter from the loaded list using its identifier.
    ///
    /// - Parameter id: The unique identifier of the reciter to find.
    /// - Returns: The `ReciterInfo` if found, or `nil` if no reciter matches the ID.
    ///
    /// ```swift
    /// if let mishary = reciterService.getReciterById(1) {
    ///     print(mishary.displayName)
    /// }
    /// ```
    public func getReciterById(_ id: Int) -> ReciterInfo? {
        return availableReciters.first(where: { $0.id == id })
    }
    
    /// Returns the audio base URL for the currently selected reciter.
    ///
    /// This is a convenience accessor equivalent to `selectedReciter?.audioBaseURL`.
    ///
    /// - Returns: The base URL for audio files, or `nil` if no reciter is selected.
    ///
    /// ```swift
    /// guard let baseURL = reciterService.getCurrentReciterBaseURL() else {
    ///     print("No reciter selected")
    ///     return
    /// }
    /// let audioURL = baseURL.appendingPathComponent("001.mp3")
    /// ```
    public func getCurrentReciterBaseURL() -> URL? {
        return selectedReciter?.audioBaseURL
    }
}

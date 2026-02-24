import Foundation
import SwiftUI
import Combine

/// Central registry that exposes available reciters and persists the selection.
///
/// `ReciterService` is responsible for:
/// - Loading available reciters from timing JSON files or embedded fallback data
/// - Managing the currently selected reciter
/// - Persisting user selection across app launches
///
/// ## Usage
/// Access the shared instance to get available reciters or change the selection:
/// ```swift
/// // Get all available reciters
/// let reciters = ReciterService.shared.availableReciters
///
/// // Select a specific reciter
/// if let reciter = ReciterService.shared.getReciterById(1) {
///     ReciterService.shared.selectReciter(reciter)
/// }
///
/// // Get the audio URL for the current reciter
/// let baseURL = ReciterService.shared.getCurrentReciterBaseURL()
/// ```
@MainActor
public final class ReciterService: ObservableObject {
    /// The shared singleton instance of `ReciterService`.
    ///
    /// Use this instance to access reciter data throughout the app.
    public static let shared = ReciterService()
    
    /// Lightweight reciter descriptor surfaced to the UI layer.
    ///
    /// This struct contains all the information needed to display and play audio from a reciter.
    /// It conforms to `Codable` for persistence and `Equatable` for comparison.
    public struct ReciterInfo: Identifiable, Equatable, Codable {
        /// Unique identifier for the reciter, matching the ID used in the timing JSON files.
        public let id: Int
        
        /// The reciter's name in Arabic script (e.g., "مشاري العفاسي").
        public let nameArabic: String
        
        /// The reciter's name in English (e.g., "Mishary Al-Afasy").
        public let nameEnglish: String
        
        /// The recitation style or transmission chain (e.g., "Hafs A'n Assem").
        public let rewaya: String
        
        /// The base URL string where the reciter's audio files are hosted.
        public let folderURL: String
        
        /// Creates a new reciter info instance.
        /// - Parameters:
        ///   - id: Unique identifier for the reciter.
        ///   - nameArabic: The reciter's name in Arabic script.
        ///   - nameEnglish: The reciter's name in English.
        ///   - rewaya: The recitation style or transmission chain.
        ///   - folderURL: The base URL string for the reciter's audio files.
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
        
        /// Localized name depending on the current locale.
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
        
        /// Base URL where the MP3 files for the reciter are hosted.
        public var audioBaseURL: URL? {
            URL(string: folderURL)
        }
    }
    
    /// List of all available reciters loaded from the timing JSON files or fallback data.
    ///
    /// This array is populated during initialization and sorted by reciter ID.
    /// Use this to display a list of reciters for the user to choose from.
    @Published public private(set) var availableReciters: [ReciterInfo] = []
    
    /// The currently selected reciter for audio playback.
    ///
    /// When changed, the selection is automatically persisted to `AppStorage`.
    /// If no reciter has been explicitly selected, the first available reciter is used as default.
    @Published public var selectedReciter: ReciterInfo? {
        didSet {
            // Save to AppStorage when reciter changes
            if let reciter = selectedReciter {
                savedReciterId = reciter.id
            }
        }
    }
    
    /// Indicates whether the service is currently loading reciter data.
    ///
    /// This is `true` during initialization and becomes `false` once all reciter
    /// information has been loaded and the default selection has been made.
    @Published public private(set) var isLoading: Bool = true
    
    @AppStorage("selectedReciterId") private var savedReciterId: Int = 0
    
    private init() {
        // Load synchronously on main thread to ensure it's ready
        loadAvailableRecitersSync()
    }
    
    /// Simple struct for decoding reciter IDs from the manifest JSON.
    private struct ReciterManifestEntry: Codable {
        let id: Int
    }
    
    /// Loads reciter IDs from the reciters_manifest.json file.
    private func loadReciterIdsFromManifest() -> [Int] {
        guard let url = Bundle.module.url(forResource: "reciters_manifest", withExtension: "json") else {
            AppLogger.shared.warn("ReciterService: reciters_manifest.json not found in bundle", category: .network)
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([ReciterManifestEntry].self, from: data)
            let ids = entries.map { $0.id }
            AppLogger.shared.info("ReciterService: Loaded \(ids.count) reciter IDs from manifest", category: .network)
            return ids
        } catch {
            AppLogger.shared.error("ReciterService: Failed to decode reciters_manifest.json: \(error.localizedDescription)", category: .network)
            return []
        }
    }
    
    private func loadAvailableRecitersSync() {
        var reciters: [ReciterInfo] = []
        
        // Load reciter IDs from JSON manifest
        let reciterIds = loadReciterIdsFromManifest()
        
        // If manifest loading failed, there's no fallback for IDs
        guard !reciterIds.isEmpty else {
            AppLogger.shared.error("ReciterService: No reciter IDs available", category: .network)
            self.isLoading = false
            return
        }
        
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
    
    /// Updates the active reciter and persists the choice to `AppStorage`.
    ///
    /// Use this method to programmatically change the selected reciter.
    /// The change will be automatically saved and restored on the next app launch.
    ///
    /// - Parameter reciter: The reciter to select.
    public func selectReciter(_ reciter: ReciterInfo) {
        selectedReciter = reciter
    }
    
    /// Fetches a reciter from the loaded list using its unique identifier.
    ///
    /// - Parameter id: The unique identifier of the reciter to find.
    /// - Returns: The `ReciterInfo` if found, or `nil` if no reciter matches the ID.
    public func getReciterById(_ id: Int) -> ReciterInfo? {
        return availableReciters.first(where: { $0.id == id })
    }
    
    /// Returns the base URL for the currently selected reciter's audio files.
    ///
    /// This is a convenience method that returns the `audioBaseURL` of the
    /// currently selected reciter, or `nil` if no reciter is selected.
    ///
    /// - Returns: The base URL for audio files, or `nil` if unavailable.
    public func getCurrentReciterBaseURL() -> URL? {
        return selectedReciter?.audioBaseURL
    }
}

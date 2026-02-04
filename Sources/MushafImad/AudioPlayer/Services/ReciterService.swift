import Foundation
import SwiftUI
import Combine

/// Central registry that exposes available reciters and persists the selection.
@MainActor
public final class ReciterService: ObservableObject {
    public static let shared = ReciterService()
    
    /// Lightweight reciter descriptor surfaced to the UI layer.
    public struct ReciterInfo: Identifiable, Equatable, Codable {
        public let id: Int
        public let nameArabic: String
        public let nameEnglish: String
        public let rewaya: String
        public let folderURL: String
        
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
    
    @Published public private(set) var availableReciters: [ReciterInfo] = []
    @Published public var selectedReciter: ReciterInfo? {
        didSet {
            // Save to AppStorage when reciter changes
            if let reciter = selectedReciter {
                savedReciterId = reciter.id
            }
        }
    }
    
    @Published public private(set) var isLoading: Bool = true
    
    @AppStorage("selectedReciterId") private var savedReciterId: Int = 0
    
    private init() {
        // Load synchronously on main thread to ensure it's ready
        loadAvailableRecitersSync()
    }
    
    /// Loads the list of available reciter IDs from the reciters_manifest.json file.
    private func loadReciterManifest() -> [ReciterInfo] {
        guard let url = Bundle.module.url(forResource: "reciters_manifest", withExtension: "json", subdirectory: "Res"),
              let data = try? Data(contentsOf: url) else {
            AppLogger.shared.warn("ReciterService: Could not load reciters_manifest.json", category: .network)
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([ReciterInfo].self, from: data)
        } catch {
            AppLogger.shared.error("ReciterService: Failed to decode reciters_manifest.json: \(error)", category: .network)
            return []
        }
    }
    
    private func loadAvailableRecitersSync() {
        var reciters: [ReciterInfo] = []
        
        // Load reciter IDs from JSON manifest
        let manifestReciters = loadReciterManifest()
        
        // Try to load detailed timing data from individual JSON files first
        var loadedFromTimingFiles = false
        for manifestReciter in manifestReciters {
            if let reciterTiming = AyahTimingService.shared.getReciter(id: manifestReciter.id) {
                let info = ReciterInfo(
                    id: reciterTiming.id,
                    nameArabic: reciterTiming.name,
                    nameEnglish: reciterTiming.name_en,
                    rewaya: reciterTiming.rewaya,
                    folderURL: reciterTiming.folder_url
                )
                reciters.append(info)
                loadedFromTimingFiles = true
            }
        }
        
        // If no reciters loaded from timing files, use the manifest data directly
        if !loadedFromTimingFiles {
            if !manifestReciters.isEmpty {
                AppLogger.shared.info("ReciterService: Using manifest data (no timing files found)", category: .network)
                reciters = manifestReciters
            } else {
                // Last resort: use ReciterDataProvider as fallback
                AppLogger.shared.warn("ReciterService: No manifest or timing files found, using embedded fallback data", category: .network)
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
    
    /// Update the active reciter and persist the choice.
    public func selectReciter(_ reciter: ReciterInfo) {
        selectedReciter = reciter
    }
    
    /// Fetch a reciter from the loaded list using its identifier.
    public func getReciterById(_ id: Int) -> ReciterInfo? {
        return availableReciters.first(where: { $0.id == id })
    }
    
    /// Convenience accessor for the currently selected reciter's audio base URL.
    public func getCurrentReciterBaseURL() -> URL? {
        return selectedReciter?.audioBaseURL
    }
}

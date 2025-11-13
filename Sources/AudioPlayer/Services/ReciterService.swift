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
            let preferredLanguage = Locale.current.language.languageCode?.identifier ?? "en"
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
        
        // Load saved reciter from AppStorage or use first available as default
        if savedReciterId > 0, let saved = reciters.first(where: { $0.id == savedReciterId }) {
            self.selectedReciter = saved
        } else if let firstReciter = reciters.first {
            // Set first reciter as default
            self.selectedReciter = firstReciter
            self.savedReciterId = firstReciter.id
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

//
//  TafseerViewModel.swift
//  MushafImad
//
//  Observable ViewModel that drives the TafseerView sheet.
//

import Foundation
import Observation

@Observable
@MainActor
public final class TafseerViewModel {

    // MARK: - Published state

    /// The tafseer text currently being displayed.
    public private(set) var tafseerText: String? = nil

    /// Loading / import progress from TafseerService.
    public private(set) var importState: TafseerImportState = .idle

    /// `true` while the service is initialising or fetching the entry.
    public private(set) var isLoading: Bool = false

    /// Error message to surface to the user if something goes wrong.
    public private(set) var errorMessage: String? = nil

    // MARK: - Current selection

    public private(set) var currentSurahId: Int = 0
    public private(set) var currentAyahId: Int = 0

    // MARK: - Private

    private let service = TafseerService.shared

    public init() {}

    // MARK: - Public API

    /// Loads tafseer for the specified ayah. Initialises the service if needed.
    public func load(surahId: Int, ayahId: Int) async {
        currentSurahId = surahId
        currentAyahId = ayahId
        tafseerText = nil
        errorMessage = nil
        isLoading = true

        // Ensure the service is ready (fetches and imports on first call)
        await service.initialize()

        // Mirror import state so the view can show progress
        importState = service.importState

        switch service.importState {
        case .ready:
            let entry = service.getTafseer(surahId: surahId, ayahId: ayahId)
            tafseerText = entry?.text
            if tafseerText == nil {
                errorMessage = String(localized: "Tafseer not available for this verse.")
            }

        case .failed(let error):
            errorMessage = error.localizedDescription

        default:
            errorMessage = String(localized: "Tafseer data is still loading.")
        }

        isLoading = false
    }

    /// Retries loading after a previous failure.
    public func retry(surahId: Int, ayahId: Int) async {
        await load(surahId: surahId, ayahId: ayahId)
    }

    /// Returns the display label for the current import state (used in progress indicators).
    public var importStateDescription: String {
        importState.localizedDescription
    }

    /// Progress value 0.0–1.0 for the import step (for ProgressView).
    public var importProgress: Double {
        importState.progressValue
    }
}

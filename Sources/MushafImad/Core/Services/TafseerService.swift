//
//  TafseerService.swift
//  MushafImad
//
//  Manages fetching, importing, and querying Tafseer Al-Jalalayn from a
//  dedicated local Realm database (tafseer.realm) stored in Application Support.
//  Data is sourced from the open alquran.cloud API on first launch and
//  cached offline from then on.
//

import Foundation
import RealmSwift

// MARK: - Error types

public enum TafseerError: Error, LocalizedError {
    case networkError(underlying: Error)
    case invalidData
    case importFailed(underlying: Error)
    case notInitialized

    public var errorDescription: String? {
        switch self {
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .invalidData:        return "The tafseer data received was invalid."
        case .importFailed(let e): return "Import failed: \(e.localizedDescription)"
        case .notInitialized:     return "TafseerService has not been initialized."
        }
    }
}

// MARK: - Import progress

public enum TafseerImportState {
    case idle
    case fetching
    case importing(progress: Double)   // 0.0 – 1.0
    case ready
    case failed(TafseerError)
}

// MARK: - Service

/// Thread-safe service that owns the `tafseer.realm` Realm file.
/// All heavy work happens off the main actor on a background queue.
@MainActor
public final class TafseerService {

    // MARK: Singleton

    public static let shared = TafseerService()

    // MARK: Public state

    public private(set) var importState: TafseerImportState = .idle

    // MARK: Private

    private var realm: Realm?
    private var realmConfiguration: Realm.Configuration?

    private let tafseerName = "jalalayn"
    private let apiURL = URL(string: "https://api.alquran.cloud/v1/quran/ar.jalalayn")!
    private let expectedAyahCount = 6236

    private init() {}

    // MARK: - Public API

    /// Returns `true` if the local tafseer database is ready for queries.
    public var isReady: Bool {
        realm != nil && importState.isReady
    }

    /// Initialises the service and imports data from the network on first launch.
    /// Safe to call multiple times — subsequent calls are no-ops once `ready`.
    /// Calling while in a `failed` state retries the import.
    public func initialize() async {
        // Skip if already ready or actively loading
        if importState.isReady { return }
        if importState.isLoading { return }

        do {
            if realm == nil {
                try setupRealm()
            }
            if needsImport() {
                await performImport()
            } else {
                importState = .ready
            }
        } catch {
            importState = .failed(.importFailed(underlying: error))
        }
    }

    /// Fetches the Tafseer entry for the given surah and ayah.
    /// Returns `nil` if not available or the service is not ready.
    public func getTafseer(surahId: Int, ayahId: Int) -> TafseerEntry? {
        guard let realm else { return nil }
        let pk = "\(tafseerName)_\(surahId)_\(ayahId)"
        return realm.object(ofType: TafseerEntry.self, forPrimaryKey: pk)?.freeze()
    }

    /// Async overload — resolves on the calling task's executor after ensuring
    /// the database is ready.
    public func getTafseerAsync(surahId: Int, ayahId: Int) async -> TafseerEntry? {
        if !isReady { await initialize() }
        return getTafseer(surahId: surahId, ayahId: ayahId)
    }

    /// Returns all entries for a given surah, sorted by ayah number.
    public func getAllTafseerForSurah(_ surahId: Int) -> [TafseerEntry] {
        guard let realm else { return [] }
        return Array(
            realm.objects(TafseerEntry.self)
                .filter("surahId == %d AND tafseerName == %@", surahId, tafseerName)
                .sorted(byKeyPath: "ayahId")
                .freeze()
        )
    }

    /// Total number of imported entries — useful for validation.
    public var importedEntryCount: Int {
        realm?.objects(TafseerEntry.self)
            .filter("tafseerName == %@", tafseerName).count ?? 0
    }

    // MARK: - Private helpers

    private func setupRealm() throws {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            throw TafseerError.notInitialized
        }

        try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        let realmURL = appSupportURL.appendingPathComponent("tafseer.realm")

        let config = Realm.Configuration(
            fileURL: realmURL,
            schemaVersion: 1,
            migrationBlock: { _, _ in }
        )
        realmConfiguration = config
        realm = try Realm(configuration: config)
    }

    private func needsImport() -> Bool {
        guard let realm else { return true }
        let count = realm.objects(TafseerEntry.self)
            .filter("tafseerName == %@", tafseerName).count
        return count < expectedAyahCount
    }

    private func performImport() async {
        importState = .fetching

        // 1. Fetch JSON from the network
        let data: Data
        do {
            let (fetchedData, response) = try await URLSession.shared.data(from: apiURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                importState = .failed(.invalidData)
                return
            }
            data = fetchedData
        } catch {
            importState = .failed(.networkError(underlying: error))
            return
        }

        // 2. Parse JSON
        let surahs: [AlQuranSurah]
        do {
            let decoded = try JSONDecoder().decode(AlQuranTafseerResponse.self, from: data)
            surahs = decoded.data.surahs
        } catch {
            importState = .failed(.invalidData)
            return
        }

        // 3. Import into Realm on a background thread
        guard let configuration = realmConfiguration else {
            importState = .failed(.notInitialized)
            return
        }

        let tafseerNameCopy = tafseerName

        // Switch to importing state before spawning the background write
        importState = .importing(progress: 0.0)

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    autoreleasepool {
                        do {
                            let bgRealm = try Realm(configuration: configuration)
                            try bgRealm.write {
                                // Remove any partial previous import
                                let stale = bgRealm.objects(TafseerEntry.self)
                                    .filter("tafseerName == %@", tafseerNameCopy)
                                bgRealm.delete(stale)

                                for surah in surahs {
                                    for ayah in surah.ayahs {
                                        let entry = TafseerEntry(
                                            surahId: surah.number,
                                            ayahId: ayah.numberInSurah,
                                            globalAyahNumber: ayah.number,
                                            text: ayah.text,
                                            tafseerName: tafseerNameCopy
                                        )
                                        bgRealm.add(entry, update: .modified)
                                    }
                                }
                            }
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }

            // Re-open the realm on the main actor after background write
            realm = try await Realm(configuration: configuration)
            importState = .ready

        } catch {
            importState = .failed(.importFailed(underlying: error))
        }
    }
}

// MARK: - TafseerImportState helpers

extension TafseerImportState {
    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var isLoading: Bool {
        switch self {
        case .fetching, .importing: return true
        default: return false
        }
    }

    var progressValue: Double {
        if case .importing(let p) = self { return p }
        return isLoading ? 0.0 : 1.0
    }

    var localizedDescription: String {
        switch self {
        case .idle:               return String(localized: "Tafseer not loaded.")
        case .fetching:           return String(localized: "Downloading tafseer data…")
        case .importing(let p):   return String(localized: "Importing tafseer (\(Int(p * 100))%)…")
        case .ready:              return String(localized: "Tafseer ready.")
        case .failed(let e):      return e.localizedDescription ?? ""
        }
    }
}

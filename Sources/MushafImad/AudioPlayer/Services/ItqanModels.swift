import Foundation

struct ItqanPaginatedResponse<T: Decodable>: Decodable {
    let count: Int?
    let next: String?
    let previous: String?
    let results: [T]
}

struct ItqanReciter: Decodable, Sendable {
    let id: Int
    let name: String?
}

struct ItqanRecitationAsset: Decodable, Sendable {
    let id: Int
    let reciterId: Int?
    let riwayahId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case reciterId = "reciter_id"
        case riwayahId = "riwayah_id"
    }
}

struct ItqanSurahTrack: Decodable, Sendable {
    let surahNumber: Int
    let surahName: String?
    let audioURL: URL?
    let durationMs: Int?
    let ayahsCount: Int?
    let ayahsTimings: [ItqanAyahTiming]

    enum CodingKeys: String, CodingKey {
        case surahNumber = "surah_number"
        case surahName = "surah_name"
        case audioURL = "audio_url"
        case durationMs = "duration_ms"
        case ayahsCount = "ayahs_count"
        case ayahsTimings = "ayahs_timings"
    }
}

struct ItqanAyahTiming: Decodable, Sendable {
    let ayahKey: String
    let startMs: Int
    let endMs: Int

    enum CodingKeys: String, CodingKey {
        case ayahKey = "ayah_key"
        case startMs = "start_ms"
        case endMs = "end_ms"
    }
}

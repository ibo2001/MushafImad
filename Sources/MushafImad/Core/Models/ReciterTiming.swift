import Foundation

public struct ReciterTiming: Codable, Sendable {
    public let id: Int
    public let name: String
    public let name_en: String
    public let rewaya: String
    public let folder_url: String
    public let chapters: [ChapterTiming]
}

public struct ChapterTiming: Codable, Sendable {
    public let id: Int
    public let name: String
    public let aya_timing: [AyahTiming]
}

public struct AyahTiming: Codable, Sendable {
    public let ayah: Int
    public let start_time: Int
    public let end_time: Int
}

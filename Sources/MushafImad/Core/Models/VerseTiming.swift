import Foundation

/// A normalized verse timing item used across timing providers.
public struct VerseTiming: Codable, Equatable, Sendable {
    public let surahId: Int
    public let ayahId: Int
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public init(surahId: Int, ayahId: Int, startTime: TimeInterval, endTime: TimeInterval) {
        self.surahId = surahId
        self.ayahId = ayahId
        self.startTime = startTime
        self.endTime = endTime
    }
}

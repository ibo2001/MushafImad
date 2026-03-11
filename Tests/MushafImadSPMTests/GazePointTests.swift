import Foundation
import Testing
@testable import MushafImad

@Test func gazePointLineComputesFromYCoordinate() {
    let top = GazePoint(x: 0.5, y: 0.0)
    #expect(top.line == 0)

    let bottom = GazePoint(x: 0.5, y: 1.0)
    #expect(bottom.line == 14)

    let middle = GazePoint(x: 0.5, y: 0.5)
    #expect(middle.line == 7)
}

@Test func gazePointLineClampsNegativeY() {
    let point = GazePoint(x: 0.5, y: -0.5)
    #expect(point.line == 0)
}

@Test func gazePointLineClampsExcessiveY() {
    let point = GazePoint(x: 0.5, y: 1.5)
    #expect(point.line == 14)
}

@Test func gazePointEquality() {
    let date = Date.now
    let a = GazePoint(x: 0.3, y: 0.7, timestamp: date, confidence: 0.9)
    let b = GazePoint(x: 0.3, y: 0.7, timestamp: date, confidence: 0.9)
    #expect(a == b)
}

@Test func gazePointDefaultConfidence() {
    let point = GazePoint(x: 0.0, y: 0.0)
    #expect(point.confidence == 1.0)
}

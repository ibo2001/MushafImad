import Foundation
import SwiftUI
import Testing
@testable import MushafImad

@Suite(.serialized)
@MainActor
class MushafRenderSourceTests {
    var recorder: RecordingRenderSourceSpy
    
    init() throws {
        let recorder = RecordingRenderSourceSpy()
        MushafRendering.configuration = MushafRenderConfiguration(renderSource: recorder)
        self.recorder = recorder
    }
    
    @MainActor
    deinit {
        MushafRendering.reset()
    }
    
    // Recording source
    @Test func testRecordingSource_EveryPageHasAllLines() {
        // Arrange, Act
        for page in 1...604 {
            for line in 0...14 {
                let context = MushafRenderContext(page: page, line: line, containerSize: CGSize(width: 375, height: 50))
                let _ = MushafRendering.configuration.renderSource.lineView(context)
            }
        }
        
        // Assert
        #expect(recorder.contexts.count == 9060)
        #expect(recorder.contexts[0].page == 1)
        #expect(recorder.contexts[0].line == 0)
        let lastContext = recorder.contexts.last!
        #expect(lastContext.page == 604)
        #expect(lastContext.line == 14)
        #expect(lastContext.containerSize.width > 0.0)
    }
    
    // Graceful degradation
    @Test func testLineImageSource_DoesNotCrash() {
        // Arrange
        let context = MushafRenderContext(page: 1, line: 0, containerSize: CGSize(width: 375, height: 50))
        
        // Act
        let _ = LineImageRenderSource().lineView(context) // the assert here is that no crash happens
    }
}


class RecordingRenderSourceSpy: MushafRenderSource {
    var contexts: [MushafRenderContext] = []
    
    func lineView(_ context: MushafRenderContext) -> AnyView {
        contexts.append(context)
        return AnyView(Text("Hello"))
    }
}

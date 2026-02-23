import Foundation
import Testing
@testable import MushafImad

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Test func itqanProviderParsesWrappedDataPayload() async throws {
    let payload = """
    {
      "data": [
        { "surah_id": 1, "ayah_id": 1, "start_time": 0, "end_time": 1250 },
        { "surah_id": 1, "ayah_id": 2, "start_time": 1250, "end_time": 2500 }
      ]
    }
    """.data(using: .utf8)!

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: configuration)

    MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
            url: try #require(request.url),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, payload)
    }

    let provider = ItqanTimingProvider(
        baseURL: URL(string: "https://itqan.test")!,
        endpointPaths: ["/api/v1/timings/verses"],
        session: session
    )

    let timings = try await provider.fetchTiming(for: 1, surahId: 1)
    #expect(timings.count == 2)
    #expect(timings[0] == VerseTiming(surahId: 1, ayahId: 1, startTime: 0, endTime: 1.25))
    #expect(timings[1] == VerseTiming(surahId: 1, ayahId: 2, startTime: 1.25, endTime: 2.5))
}

@Test func itqanProviderKeepsSecondsPayloadWithoutRescaling() async throws {
    let payload = """
    {
      "data": [
        { "surah_id": 1, "ayah_id": 1, "start_time": 0.0, "end_time": 1.4 },
        { "surah_id": 1, "ayah_id": 2, "start_time": 1.4, "end_time": 2.8 }
      ]
    }
    """.data(using: .utf8)!

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: configuration)

    MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
            url: try #require(request.url),
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, payload)
    }

    let provider = ItqanTimingProvider(
        baseURL: URL(string: "https://itqan.test")!,
        endpointPaths: ["/api/v1/timings/verses"],
        session: session
    )

    let timings = try await provider.fetchTiming(for: 1, surahId: 1)
    #expect(timings.count == 2)
    #expect(timings[0] == VerseTiming(surahId: 1, ayahId: 1, startTime: 0.0, endTime: 1.4))
    #expect(timings[1] == VerseTiming(surahId: 1, ayahId: 2, startTime: 1.4, endTime: 2.8))
}

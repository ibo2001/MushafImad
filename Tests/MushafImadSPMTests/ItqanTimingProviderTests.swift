import Foundation
import Testing
@testable import MushafImad

@Suite(.serialized)
struct ItqanTimingProviderTests {
    final class MockURLProtocol: URLProtocol, @unchecked Sendable {
        static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

        override static func canInit(with request: URLRequest) -> Bool { true }
        override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

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

    private func makeProvider(payload: Data) -> ItqanTimingProvider {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let apiClient = ItqanAPIClient(baseURL: URL(string: "https://itqan.test")!, session: session, ttl: 60)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, payload)
        }

        return ItqanTimingProvider(apiClient: apiClient)
    }

    @Test func itqanProviderParsesSurahTrackPayload() async throws {
        let payload = """
        {
          "count": 114,
          "next": null,
          "previous": null,
          "results": [
            {
              "surah_number": 1,
              "surah_name": "Al-Fatihah",
              "audio_url": "https://cdn.itqan.dev/assets/11/001.mp3",
              "duration_ms": 54000,
              "ayahs_count": 7,
              "ayahs_timings": [
                { "ayah_key": "1:1", "start_ms": 0, "end_ms": 5200 },
                { "ayah_key": "1:2", "start_ms": 5200, "end_ms": 9800 }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let provider = makeProvider(payload: payload)
        let data = try await provider.fetchChapterData(for: 1001, surahId: 1)

        #expect(data.timings.count == 2)
        #expect(data.timings[0] == VerseTiming(surahId: 1, ayahId: 1, startTime: 0.0, endTime: 5.2))
        #expect(data.timings[1] == VerseTiming(surahId: 1, ayahId: 2, startTime: 5.2, endTime: 9.8))
        #expect(data.audioURL == URL(string: "https://cdn.itqan.dev/assets/11/001.mp3"))
    }

    @Test func itqanProviderUsesAssetIdEndpoint() async throws {
        let payload = """
        { "count": 0, "next": null, "previous": null, "results": [] }
        """.data(using: .utf8)!

        let provider = makeProvider(payload: payload)

        MockURLProtocol.requestHandler = { request in
            let url = try #require(request.url)
            #expect(url.path.contains("/recitations/11/"))
            #expect(url.query?.contains("page=1") == true)
            #expect(url.query?.contains("page_size=114") == true)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, payload)
        }

        await #expect(throws: TimingProviderError.self) {
            _ = try await provider.fetchChapterData(for: 1001, surahId: 1)
        }
    }

    @Test func itqanProviderThrowsForNonItqanReciter() async {
        let provider = makeProvider(payload: Data("{}".utf8))
        await #expect(throws: TimingProviderError.self) {
            _ = try await provider.fetchChapterData(for: 5, surahId: 1)
        }
    }
}

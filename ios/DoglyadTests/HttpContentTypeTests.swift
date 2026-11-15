import DoglyadNetwork
import Foundation
import Testing

@Suite(
    .serialized,
)
struct HttpContentTypeTests {
    init() {}

    @Test
    func sessionDefaultsApplyToGetAndPostAndExplicitHeadersWin() async throws {
        let server = try HttpTestServer()
        let baseURL = try await server.start()
        defer {
            server.stop()
        }
        let client: any DHttpClientProtocol = DHttpClient(
            baseUrl: baseURL,
            baseVersionPrefix: "/v1",
        )
        let get: [String: String] = try await client.get(
            endPoint: "/echo",
            headers: ["X-Test": "kept"],
        )
        #expect(
            get[
                "contentType",
            ] == "application/json",
        )
        #expect(
            get[
                "custom",
            ] == "kept",
        )
        let json: [String: String] = try await client.post(
            endPoint: "/echo",
            body: ["value": "test"],
        )
        #expect(
            json[
                "contentType",
            ] == "application/json",
        )
        let data: [String: String] = try await client.post(
            endPoint: "/echo",
            data: Data(
                "{}".utf8,
            ),
        )
        #expect(
            data[
                "contentType",
            ] == "application/json",
        )
        let audio: [String: String] = try await client.post(
            endPoint: "/echo",
            data: Data(
                [0, 0],
            ),
            headers: ["content-type": "application/octet-stream", "X-Test": "audio"],
        )
        #expect(
            audio[
                "contentType",
            ] == "application/octet-stream",
        )
        #expect(
            audio[
                "custom",
            ] == "audio",
        )
        client.updateConfiguration(
            timeoutIntervalForRequest: 20,
            timeoutIntervalForResource: 30,
        )
        let configured: [String: String] = try await client.get(
            url: URL(
                string: baseURL + "/echo",
            )!,
        )
        #expect(
            configured[
                "contentType",
            ] == "application/json",
        )
    }
}

import DoglyadNetwork
import Foundation
import Testing

struct HttpQueryParametersTests {
    init() {}

    @Test
    func everyRequestMethodEncodesQueryWithoutChangingBodyOrHeaders() async throws {
        let server = try HttpTestServer()
        let baseURL = try await server.start()
        defer {
            server.stop()
        }
        let client: any DHttpClientProtocol = DHttpClient(
            baseUrl: baseURL,
            baseVersionPrefix: "/v1",
        )
        let value = "модель A+B&C=1 /?#%"
        let parameters = ["model": value, "empty": ""]
        let endpoint = "/echo?existing=keep%2Bvalue&repeat=1&repeat=2"

        let get: [String: String] = try await client.get(
            endPoint: endpoint,
            queryParameters: parameters,
            headers: ["X-Test": "kept"],
        )
        let expected = try #require(
            get[
                "target",
            ],
        )
        let components = try #require(
            URLComponents(
                string: expected,
            ),
        )
        #expect(
            components.path == "/v1/echo",
        )
        #expect(
            components.queryItems?.first(
                where: {
                    $0.name == "model"
                },
            )?.value == value,
        )
        #expect(
            components.queryItems?.first(
                where: {
                    $0.name == "empty"
                },
            )?.value == "",
        )
        #expect(
            components.queryItems?.first(
                where: {
                    $0.name == "existing"
                },
            )?.value == "keep+value",
        )
        #expect(
            components.queryItems?.filter {
                $0.name == "repeat"
            }.compactMap(
                \.value,
            ) == ["1", "2"],
        )
        #expect(
            expected.contains(
                "A%2BB",
            ),
        )
        #expect(
            get[
                "custom",
            ] == "kept",
        )
        let direct: [String: String] = try await client.get(
            url: URL(
                string: baseURL + "/v1" + endpoint + "#fragment",
            )!,
            queryParameters: parameters,
        )
        #expect(
            direct[
                "target",
            ] == expected,
        )
        let getBody: [String: String] = try await client.get(
            endPoint: endpoint,
            queryParameters: parameters,
            body: String?.none,
        )
        #expect(
            getBody[
                "target",
            ] == expected,
        )
        let post: [String: String] = try await client.post(
            endPoint: endpoint,
            queryParameters: parameters,
            body: ["message": "unchanged"],
        )
        #expect(
            post[
                "target",
            ] == expected,
        )
        let jsonBody = try JSONDecoder().decode(
            [String: String].self,
            from: Data(
                base64Encoded: post[
                    "body",
                ]!,
            )!,
        )
        #expect(
            jsonBody == ["message": "unchanged"],
        )
        let audio = Data(
            [0, 1, 255, 254],
        )
        let binary: [String: String] = try await client.post(
            endPoint: endpoint,
            queryParameters: parameters,
            data: audio,
            headers: ["Content-Type": "application/octet-stream"],
        )
        #expect(
            binary[
                "target",
            ] == expected,
        )
        #expect(
            binary[
                "body",
            ] == audio.base64EncodedString(),
        )
        #expect(
            binary[
                "contentType",
            ] == "application/octet-stream",
        )
        try await client.post(
            endPoint: endpoint,
            queryParameters: parameters,
            body: ["message": "no response"],
        )
        #expect(
            server.receivedTargets.last == expected,
        )
        let stream = try await client.serverEvents(
            endPoint: endpoint,
            queryParameters: parameters,
        )
        var eventCount = 0
        for try await event in stream {
            let echoed = try JSONDecoder().decode(
                [String: String].self,
                from: event.data,
            )
            #expect(
                echoed[
                    "target",
                ] == expected,
            )
            eventCount += 1
        }
        #expect(
            eventCount == 1,
        )
        let unchanged: [String: String] = try await client.get(
            endPoint: endpoint,
            queryParameters: [:],
        )
        #expect(
            unchanged[
                "target",
            ] == "/v1" + endpoint,
        )
    }
}

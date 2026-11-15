import DoglyadNetwork
import Foundation

actor RobokassaTestHttpClient: DHttpClientProtocol {
    let baseUrl = "https://api.example"
    let baseVersionPrefix = "/v1"
    private(set) var requests: [String] = []
    private(set) var requestBodies: [String: Data] = [:]
    private let responses: [String: Data]

    init(
        responses: [String: Data],
    ) {
        self.responses = responses
    }

    nonisolated func updateConfiguration(
        timeoutIntervalForRequest _: TimeInterval,
        timeoutIntervalForResource _: TimeInterval,
    ) {}

    func get<Response: Decodable>(
        url _: URL,
        queryParameters _: [String: String]?,
    ) async throws -> Response {
        throw URLError(
            .unsupportedURL,
        )
    }

    func get<Response: Decodable>(
        endPoint: String,
        queryParameters _: [String: String]?,
        headers _: [String: String]?,
    ) async throws -> Response {
        requests.append(
            endPoint,
        )
        guard let data = responses[
            endPoint,
        ] else {
            throw URLError(
                .unsupportedURL,
            )
        }
        return try JSONDecoder().decode(
            Response.self,
            from: data,
        )
    }

    func get<Response: Decodable>(
        endPoint _: String,
        queryParameters _: [String: String]?,
        body _: (some Encodable & Sendable)?,
        headers _: [String: String]?,
    ) async throws -> Response {
        throw URLError(
            .unsupportedURL,
        )
    }

    func post<Response: Decodable>(
        endPoint: String,
        queryParameters _: [String: String]?,
        body: (some Encodable & Sendable)?,
        headers _: [String: String]?,
        encoderUserInfo _: [CodingUserInfoKey: Any]?,
    ) async throws -> Response {
        if let body {
            requestBodies[
                endPoint,
            ] = try {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                return try encoder.encode(
                    body,
                )
            }()
        }
        requests.append(
            endPoint,
        )
        guard let data = responses[
            endPoint,
        ] else {
            throw URLError(
                .unsupportedURL,
            )
        }
        return try JSONDecoder().decode(
            Response.self,
            from: data,
        )
    }

    func post(
        endPoint _: String,
        queryParameters _: [String: String]?,
        body _: (some Encodable & Sendable)?,
        headers _: [String: String]?,
        encoderUserInfo _: [CodingUserInfoKey: Any]?,
    ) async throws {
        throw URLError(
            .unsupportedURL,
        )
    }

    func post<Response: Decodable>(
        endPoint _: String,
        queryParameters _: [String: String]?,
        data _: Data?,
        headers _: [String: String]?,
    ) async throws -> Response {
        throw URLError(
            .unsupportedURL,
        )
    }

    func serverEvents(
        endPoint _: String,
        queryParameters _: [String: String]?,
        headers _: [String: String]?,
    ) async throws -> AsyncThrowingStream<DServerEvent, Error> {
        throw URLError(
            .unsupportedURL,
        )
    }
}

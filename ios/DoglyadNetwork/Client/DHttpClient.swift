public import Foundation
internal import Alamofire

public final class DHttpClient: DHttpClientProtocol {
    public let baseUrl: String
    public let baseVersionPrefix: String
    /// Rebuilt by `updateConfiguration`, hence a `var`.
    private var session: Session
    /// Kept so the session can be rebuilt with the same interceptors and order.
    private let interceptors: [any DHttpInterceptorProtocol]
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init(
        baseUrl: String,
        baseVersionPrefix: String,
        interceptors: [any DHttpInterceptorProtocol] = [],
    ) {
        self.baseUrl = baseUrl
        self.baseVersionPrefix = baseVersionPrefix

        // Placeholders until the remote config arrives; see NetworkConfig.default.
        session = Self.makeSession(
            interceptors: interceptors,
            timeoutIntervalForRequest: 300,
            timeoutIntervalForResource: 300,
        )
        self.interceptors = interceptors
    }

    private var baseApiUrl: String {
        baseUrl + baseVersionPrefix
    }

    public func updateConfiguration(
        timeoutIntervalForRequest: TimeInterval,
        timeoutIntervalForResource: TimeInterval,
    ) {
        session = Self.makeSession(
            interceptors: interceptors,
            timeoutIntervalForRequest: timeoutIntervalForRequest,
            timeoutIntervalForResource: timeoutIntervalForResource,
        )
    }

    public func get<Response: Decodable>(
        url: URL,
        queryParameters: [String: String]? = nil,
    ) async throws -> Response {
        let response = try await session.request(
            makeURL(
                url.absoluteString,
                queryParameters: queryParameters,
            ),
            method: .get,
        )
        .validate()
        .serializingDecodable(
            Response.self,
            decoder: jsonDecoder,
        )
        .response
        return try response.result.get()
    }

    public func get<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        headers: [String: String]? = nil,
    ) async throws -> Response {
        let response = try await session.request(
            makeURL(
                baseApiUrl + endPoint,
                queryParameters: queryParameters,
            ),
            method: .get,
            headers: headers.map(
                HTTPHeaders.init,
            ) ?? HTTPHeaders(),
        )
        .validate()
        .serializingDecodable(
            Response.self,
            decoder: jsonDecoder,
        )
        .response
        return try response.result.get()
    }

    public func get<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        body: (some Encodable & Sendable)? = String?.none,
        headers: [String: String]? = nil,
    ) async throws -> Response {
        let response = try await session.request(
            makeURL(
                baseApiUrl + endPoint,
                queryParameters: queryParameters,
            ),
            method: .get,
            parameters: body,
            encoder: JSONParameterEncoder(
                encoder: jsonEncoder,
            ),
            headers: headers.map(
                HTTPHeaders.init,
            ) ?? HTTPHeaders(),
        )
        .validate()
        .serializingDecodable(
            Response.self,
            decoder: jsonDecoder,
        )
        .response
        return try response.result.get()
    }

    public func post<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        body: (some Encodable & Sendable)? = String?.none,
        headers: [String: String]? = nil,
        encoderUserInfo: [CodingUserInfoKey: Any]? = nil,
    ) async throws -> Response {
        let encoder: JSONEncoder
        if let encoderUserInfo {
            encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.userInfo = encoderUserInfo
        } else {
            encoder = jsonEncoder
        }

        let response = try await session.request(
            makeURL(
                baseApiUrl + endPoint,
                queryParameters: queryParameters,
            ),
            method: .post,
            parameters: body,
            encoder: JSONParameterEncoder(
                encoder: encoder,
            ),
            headers: headers.map(
                HTTPHeaders.init,
            ) ?? HTTPHeaders(),
        )
        .validate()
        .serializingDecodable(
            Response.self,
            decoder: jsonDecoder,
        )
        .response
        return try response.result.get()
    }

    public func post(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        body: (some Encodable & Sendable)? = String?.none,
        headers: [String: String]? = nil,
        encoderUserInfo: [CodingUserInfoKey: Any]? = nil,
    ) async throws {
        let encoder: JSONEncoder
        if let encoderUserInfo {
            encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.userInfo = encoderUserInfo
        } else {
            encoder = jsonEncoder
        }

        let response = try await session.request(
            makeURL(
                baseApiUrl + endPoint,
                queryParameters: queryParameters,
            ),
            method: .post,
            parameters: body,
            encoder: JSONParameterEncoder(
                encoder: encoder,
            ),
            headers: headers.map(
                HTTPHeaders.init,
            ) ?? HTTPHeaders(),
        )
        .validate()
        .serializingData(
            emptyResponseCodes: [204],
        )
        .response
        _ = try response.result.get()
    }

    public func post<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        data: Data?,
        headers: [String: String]? = nil,
    ) async throws -> Response {
        let url = try makeURL(
            baseApiUrl + endPoint,
            queryParameters: queryParameters,
        )
        var request = URLRequest(
            url: url,
        )
        request.httpMethod = "POST"
        request.httpBody = data
        request.allHTTPHeaderFields = headers
        return try await session.request(
            request,
        ).validate().serializingDecodable(
            Response.self,
            decoder: jsonDecoder,
        ).value
    }

    public func serverEvents(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        headers: [String: String]? = nil,
    ) async throws -> AsyncThrowingStream<DServerEvent, Error> {
        let url = try makeURL(
            baseApiUrl + endPoint,
            queryParameters: queryParameters,
        )
        var request = URLRequest(
            url: url,
            timeoutInterval: 30,
        )
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        request.setValue(
            "text/event-stream",
            forHTTPHeaderField: "Accept",
        )
        let streamRequest = session.streamRequest(
            request,
        ).validate()
        return AsyncThrowingStream { continuation in
            let task = Task {
                var decoder = DServerEventDecoder()
                do {
                    for await value in streamRequest.streamTask().streamingData() {
                        try Task.checkCancellation()
                        switch value.event {
                        case let .stream(
                            result,
                        ):
                            for event in try decoder.append(
                                result.get(),
                            ) {
                                continuation.yield(
                                    event,
                                )
                            }
                        case let .complete(
                            completion,
                        ):
                            if let error = completion.error {
                                throw error
                            }
                            try decoder.finish()
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: error,
                    )
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                streamRequest.cancel()
            }
        }
    }

    private func makeURL(
        _ value: String,
        queryParameters: [String: String]?,
    ) throws -> URL {
        guard var components = URLComponents(
            string: value,
        ) else {
            throw URLError(
                .badURL,
            )
        }
        if let queryParameters, !queryParameters.isEmpty {
            var query = URLComponents()
            query.queryItems = queryParameters.sorted {
                $0.key < $1.key
            }.map {
                URLQueryItem(
                    name: $0.key,
                    value: $0.value,
                )
            }
            // Form-style query decoders treat a literal plus as a space. Encode
            // new values without changing the existing URL's query semantics.
            let encoded = query.percentEncodedQuery?.replacingOccurrences(
                of: "+",
                with: "%2B",
            )
            components.percentEncodedQuery = [components.percentEncodedQuery, encoded]
                .compactMap(
                    \.self,
                )
                .filter {
                    !$0.isEmpty
                }
                .joined(
                    separator: "&",
                )
        }
        guard let url = components.url else {
            throw URLError(
                .badURL,
            )
        }
        return url
    }

    private static func makeSession(
        interceptors: [any DHttpInterceptorProtocol],
        timeoutIntervalForRequest: TimeInterval,
        timeoutIntervalForResource: TimeInterval,
    ) -> Session {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["Content-Type": "application/json"]
        configuration.timeoutIntervalForRequest = timeoutIntervalForRequest
        configuration.timeoutIntervalForResource = timeoutIntervalForResource
        return Session(
            configuration: configuration,
            interceptor: interceptors.isEmpty ? nil : DHttpInterceptorAdapter(
                interceptors: interceptors,
            ),
        )
    }
}

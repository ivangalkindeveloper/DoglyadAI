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
        self.interceptors = interceptors

        // Placeholders until the remote config arrives; see NetworkConfig.default.
        session = Self.makeSession(
            interceptors: interceptors,
            timeoutIntervalForRequest: 300,
            timeoutIntervalForResource: 300,
        )
    }

    private var baseApiUrl: String {
        baseUrl + baseVersionPrefix
    }

    public func updateConfiguration(
        timeoutIntervalForRequest: TimeInterval,
        timeoutIntervalForResource: TimeInterval,
    ) {
        // URLSession copies its configuration when created, so mutating the old one is a
        // no-op — the session has to be replaced for new timeouts to take effect. Safe
        // during initialization: nothing is in flight yet.
        session = Self.makeSession(
            interceptors: interceptors,
            timeoutIntervalForRequest: timeoutIntervalForRequest,
            timeoutIntervalForResource: timeoutIntervalForResource,
        )
    }

    private static func makeSession(
        interceptors: [any DHttpInterceptorProtocol],
        timeoutIntervalForRequest: TimeInterval,
        timeoutIntervalForResource: TimeInterval,
    ) -> Session {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutIntervalForRequest
        configuration.timeoutIntervalForResource = timeoutIntervalForResource
        return Session(
            configuration: configuration,
            interceptor: interceptors.isEmpty ? nil : DHttpInterceptorAdapter(
                interceptors: interceptors,
            ),
        )
    }

    public func get<Response: Decodable>(
        url: URL,
    ) async throws -> Response {
        let response = await session.request(
            url,
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
        headers: [String: String]? = nil,
    ) async throws -> Response {
        let response = await session.request(
            baseApiUrl + endPoint,
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
        body: (some Encodable & Sendable)? = nil,
        headers: [String: String]? = nil,
    ) async throws -> Response {
        let response = await session.request(
            baseApiUrl + endPoint,
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
        body: (some Encodable & Sendable)? = nil,
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

        let response = await session.request(
            baseApiUrl + endPoint,
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
        body: (some Encodable & Sendable)? = nil,
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

        let response = await session.request(
            baseApiUrl + endPoint,
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
}

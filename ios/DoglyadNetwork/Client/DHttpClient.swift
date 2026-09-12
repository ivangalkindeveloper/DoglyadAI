public import Foundation
internal import Alamofire

public final class DHttpClient: DHttpClientProtocol {
    public let baseUrl: String
    public let baseVersionPrefix: String

    /// Rebuilt by `updateConfiguration`, hence a `var`.
    private var session: Session
    /// Kept so the session can be rebuilt with the same interceptor.
    private let interceptor: DHttpInterceptorProtocol?

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

    private var baseApiUrl: String {
        baseUrl + baseVersionPrefix
    }

    public init(
        baseUrl: String,
        baseVersionPrefix: String,
        interceptor: DHttpInterceptorProtocol? = nil
    ) {
        self.baseUrl = baseUrl
        self.baseVersionPrefix = baseVersionPrefix
        self.interceptor = interceptor

        // Placeholders until the remote config arrives; see NetworkConfig.default.
        session = Self.makeSession(
            interceptor: interceptor,
            timeoutIntervalForRequest: 300,
            timeoutIntervalForResource: 300
        )
    }

    public func updateConfiguration(
        timeoutIntervalForRequest: TimeInterval,
        timeoutIntervalForResource: TimeInterval
    ) {
        // URLSession copies its configuration when created, so mutating the old one is a
        // no-op — the session has to be replaced for new timeouts to take effect. Safe
        // during initialization: nothing is in flight yet.
        session = Self.makeSession(
            interceptor: interceptor,
            timeoutIntervalForRequest: timeoutIntervalForRequest,
            timeoutIntervalForResource: timeoutIntervalForResource
        )
    }

    private static func makeSession(
        interceptor: DHttpInterceptorProtocol?,
        timeoutIntervalForRequest: TimeInterval,
        timeoutIntervalForResource: TimeInterval
    ) -> Session {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutIntervalForRequest
        configuration.timeoutIntervalForResource = timeoutIntervalForResource
        return Session(
            configuration: configuration,
            interceptor: interceptor.map(DHttpInterceptorAdapter.init)
        )
    }

    public func get<Response: Decodable>(
        url: URL
    ) async throws -> Response {
        let response = await session.request(
            url,
            method: .get
        )
        .validate()
        .serializingDecodable(Response.self, decoder: jsonDecoder)
        .response
        return try response.result.get()
    }

    public func get<Response: Decodable>(
        endPoint: String,
        headers: [String: String]? = nil
    ) async throws -> Response {
        let response = await session.request(
            baseApiUrl + endPoint,
            method: .get,
            headers: headers.map(HTTPHeaders.init) ?? HTTPHeaders()
        )
        .validate()
        .serializingDecodable(Response.self, decoder: jsonDecoder)
        .response
        return try response.result.get()
    }

    public func get<Body: Encodable & Sendable, Response: Decodable>(
        endPoint: String,
        body: Body? = nil,
        headers: [String: String]? = nil
    ) async throws -> Response {
        let response = await session.request(
            baseApiUrl + endPoint,
            method: .get,
            parameters: body,
            encoder: JSONParameterEncoder(encoder: jsonEncoder),
            headers: headers.map(HTTPHeaders.init) ?? HTTPHeaders()
        )
        .validate()
        .serializingDecodable(Response.self, decoder: jsonDecoder)
        .response
        return try response.result.get()
    }

    public func post<Body: Encodable & Sendable, Response: Decodable>(
        endPoint: String,
        body: Body? = nil,
        headers: [String: String]? = nil,
        encoderUserInfo: [CodingUserInfoKey: Any]? = nil
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
            encoder: JSONParameterEncoder(encoder: encoder),
            headers: headers.map(HTTPHeaders.init) ?? HTTPHeaders()
        )
        .validate()
        .serializingDecodable(Response.self, decoder: jsonDecoder)
        .response
        return try response.result.get()
    }

    public func post<Body: Encodable & Sendable>(
        endPoint: String,
        body: Body? = nil,
        headers: [String: String]? = nil,
        encoderUserInfo: [CodingUserInfoKey: Any]? = nil
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
            encoder: JSONParameterEncoder(encoder: encoder),
            headers: headers.map(HTTPHeaders.init) ?? HTTPHeaders()
        )
        .validate()
        .serializingData(emptyResponseCodes: [204])
        .response
        _ = try response.result.get()
    }
}

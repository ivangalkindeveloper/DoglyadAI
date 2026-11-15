public import Foundation

public protocol DHttpClientProtocol {
    var baseUrl: String {
        get
    }
    var baseVersionPrefix: String {
        get
    }

    func updateConfiguration(
        timeoutIntervalForRequest: TimeInterval,
        timeoutIntervalForResource: TimeInterval,
    )

    func get<Response: Decodable>(
        url: URL,
        queryParameters: [String: String]?,
    ) async throws -> Response

    func get<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]?,
        headers: [String: String]?,
    ) async throws -> Response

    func get<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]?,
        body: (some Encodable & Sendable)?,
        headers: [String: String]?,
    ) async throws -> Response

    func post<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]?,
        body: (some Encodable & Sendable)?,
        headers: [String: String]?,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws -> Response

    func post(
        endPoint: String,
        queryParameters: [String: String]?,
        body: (some Encodable & Sendable)?,
        headers: [String: String]?,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws

    func post<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]?,
        data: Data?,
        headers: [String: String]?,
    ) async throws -> Response

    func serverEvents(
        endPoint: String,
        queryParameters: [String: String]?,
        headers: [String: String]?,
    ) async throws -> AsyncThrowingStream<DServerEvent, Error>
}

public extension DHttpClientProtocol {
    func get<Response: Decodable>(
        url: URL,
    ) async throws -> Response {
        try await get(
            url: url,
            queryParameters: nil,
        )
    }

    func get<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]? = nil,
    ) async throws -> Response {
        try await get(
            endPoint: endPoint,
            queryParameters: queryParameters,
            headers: nil,
        )
    }

    func get<Response: Decodable>(
        endPoint: String,
        headers: [String: String]?,
    ) async throws -> Response {
        try await get(
            endPoint: endPoint,
            queryParameters: nil,
            headers: headers,
        )
    }

    func get<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        body: (some Encodable & Sendable)?,
    ) async throws -> Response {
        try await get(
            endPoint: endPoint,
            queryParameters: queryParameters,
            body: body,
            headers: nil,
        )
    }

    func get<Response: Decodable>(
        endPoint: String,
        body: (some Encodable & Sendable)?,
        headers: [String: String]?,
    ) async throws -> Response {
        try await get(
            endPoint: endPoint,
            queryParameters: nil,
            body: body,
            headers: headers,
        )
    }

    func post<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        body: (some Encodable & Sendable)? = String?.none,
        headers: [String: String]? = nil,
    ) async throws -> Response {
        try await post(
            endPoint: endPoint,
            queryParameters: queryParameters,
            body: body,
            headers: headers,
            encoderUserInfo: nil,
        )
    }

    func post<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        body: (some Encodable & Sendable)? = String?.none,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws -> Response {
        try await post(
            endPoint: endPoint,
            queryParameters: queryParameters,
            body: body,
            headers: nil,
            encoderUserInfo: encoderUserInfo,
        )
    }

    func post<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        headers: [String: String]?,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws -> Response {
        try await post(
            endPoint: endPoint,
            queryParameters: queryParameters,
            body: String?.none,
            headers: headers,
            encoderUserInfo: encoderUserInfo,
        )
    }

    func post<Response: Decodable>(
        endPoint: String,
        body: (some Encodable & Sendable)?,
        headers: [String: String]?,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws -> Response {
        try await post(
            endPoint: endPoint,
            queryParameters: nil,
            body: body,
            headers: headers,
            encoderUserInfo: encoderUserInfo,
        )
    }

    func post(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        body: (some Encodable & Sendable)? = String?.none,
        headers: [String: String]? = nil,
    ) async throws {
        try await post(
            endPoint: endPoint,
            queryParameters: queryParameters,
            body: body,
            headers: headers,
            encoderUserInfo: nil,
        )
    }

    func post(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        body: (some Encodable & Sendable)? = String?.none,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws {
        try await post(
            endPoint: endPoint,
            queryParameters: queryParameters,
            body: body,
            headers: nil,
            encoderUserInfo: encoderUserInfo,
        )
    }

    func post(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        headers: [String: String]?,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws {
        try await post(
            endPoint: endPoint,
            queryParameters: queryParameters,
            body: String?.none,
            headers: headers,
            encoderUserInfo: encoderUserInfo,
        )
    }

    func post(
        endPoint: String,
        body: (some Encodable & Sendable)?,
        headers: [String: String]?,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws {
        try await post(
            endPoint: endPoint,
            queryParameters: nil,
            body: body,
            headers: headers,
            encoderUserInfo: encoderUserInfo,
        )
    }

    func post<Response: Decodable>(
        endPoint: String,
        queryParameters: [String: String]? = nil,
        data: Data?,
    ) async throws -> Response {
        try await post(
            endPoint: endPoint,
            queryParameters: queryParameters,
            data: data,
            headers: nil,
        )
    }

    func post<Response: Decodable>(
        endPoint: String,
        data: Data?,
        headers: [String: String]?,
    ) async throws -> Response {
        try await post(
            endPoint: endPoint,
            queryParameters: nil,
            data: data,
            headers: headers,
        )
    }

    func serverEvents(
        endPoint: String,
        queryParameters: [String: String]? = nil,
    ) async throws -> AsyncThrowingStream<DServerEvent, Error> {
        try await serverEvents(
            endPoint: endPoint,
            queryParameters: queryParameters,
            headers: nil,
        )
    }

    func serverEvents(
        endPoint: String,
        headers: [String: String]?,
    ) async throws -> AsyncThrowingStream<DServerEvent, Error> {
        try await serverEvents(
            endPoint: endPoint,
            queryParameters: nil,
            headers: headers,
        )
    }
}

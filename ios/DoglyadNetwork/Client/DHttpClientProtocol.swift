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
    ) async throws -> Response

    func get<Response: Decodable>(
        endPoint: String,
        headers: [String: String]?,
    ) async throws -> Response

    func get<Response: Decodable>(
        endPoint: String,
        body: (some Encodable & Sendable)?,
        headers: [String: String]?,
    ) async throws -> Response

    func post<Response: Decodable>(
        endPoint: String,
        body: (some Encodable & Sendable)?,
        headers: [String: String]?,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws -> Response

    func post(
        endPoint: String,
        body: (some Encodable & Sendable)?,
        headers: [String: String]?,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws

    func post<Response: Decodable>(
        endPoint: String,
        data: Data?,
        headers: [String: String]?,
    ) async throws -> Response

    func serverEvents(
        endPoint: String,
        headers: [String: String]?,
    ) async throws -> AsyncThrowingStream<DServerEvent, Error>
}

// Protocol requirements cannot declare default arguments. These overloads
// supply omitted values and call the full requirements through their witnesses.
// A typed nil lets Swift infer the generic body type when the body is omitted.
public extension DHttpClientProtocol {
    func get<Response: Decodable>(
        endPoint: String,
    ) async throws -> Response {
        try await get(
            endPoint: endPoint,
            headers: nil,
        )
    }

    func get<Response: Decodable>(
        endPoint: String,
        body: (some Encodable & Sendable)?,
    ) async throws -> Response {
        try await get(
            endPoint: endPoint,
            body: body,
            headers: nil,
        )
    }

    func post<Response: Decodable>(
        endPoint: String,
        body: (some Encodable & Sendable)? = String?.none,
        headers: [String: String]? = nil,
    ) async throws -> Response {
        try await post(
            endPoint: endPoint,
            body: body,
            headers: headers,
            encoderUserInfo: nil,
        )
    }

    func post<Response: Decodable>(
        endPoint: String,
        body: (some Encodable & Sendable)? = String?.none,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws -> Response {
        try await post(
            endPoint: endPoint,
            body: body,
            headers: nil,
            encoderUserInfo: encoderUserInfo,
        )
    }

    func post<Response: Decodable>(
        endPoint: String,
        headers: [String: String]?,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws -> Response {
        try await post(
            endPoint: endPoint,
            body: String?.none,
            headers: headers,
            encoderUserInfo: encoderUserInfo,
        )
    }

    func post(
        endPoint: String,
        body: (some Encodable & Sendable)? = String?.none,
        headers: [String: String]? = nil,
    ) async throws {
        try await post(
            endPoint: endPoint,
            body: body,
            headers: headers,
            encoderUserInfo: nil,
        )
    }

    func post(
        endPoint: String,
        body: (some Encodable & Sendable)? = String?.none,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws {
        try await post(
            endPoint: endPoint,
            body: body,
            headers: nil,
            encoderUserInfo: encoderUserInfo,
        )
    }

    func post(
        endPoint: String,
        headers: [String: String]?,
        encoderUserInfo: [CodingUserInfoKey: Any]?,
    ) async throws {
        try await post(
            endPoint: endPoint,
            body: String?.none,
            headers: headers,
            encoderUserInfo: encoderUserInfo,
        )
    }

    func post<Response: Decodable>(
        endPoint: String,
        data: Data?,
    ) async throws -> Response {
        try await post(
            endPoint: endPoint,
            data: data,
            headers: nil,
        )
    }

    func serverEvents(
        endPoint: String,
    ) async throws -> AsyncThrowingStream<DServerEvent, Error> {
        try await serverEvents(
            endPoint: endPoint,
            headers: nil,
        )
    }
}

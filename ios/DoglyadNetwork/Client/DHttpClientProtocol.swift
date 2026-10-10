public import Foundation

public protocol DHttpClientProtocol {
    var baseUrl: String { get }
    var baseVersionPrefix: String { get }

    /// Applies new timeouts to every subsequent request.
    ///
    /// - Parameters:
    ///   - timeoutIntervalForRequest: how long to wait for the next chunk of data; the
    ///     timer resets on every byte, so it only fires when the connection stalls.
    ///   - timeoutIntervalForResource: the deadline for a whole request, counted from its
    ///     start regardless of activity.
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
}

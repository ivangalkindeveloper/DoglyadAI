import Foundation

public protocol DSecurityDatabaseProtocol: Sendable {
    func fetchRequestLimit<T: Sendable>(
        _ transform: @Sendable (RequestLimitDB?) -> T,
    ) async throws -> T

    func setRequestLimit(
        value: RequestLimitDB,
    ) async throws

    func clearRequestLimit() async throws

    func incrementRequestCount() async throws
}

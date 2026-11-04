public import Foundation

public protocol DHttpInterceptorProtocol: Sendable {
    func adapt(
        _ urlRequest: URLRequest,
    ) async throws -> URLRequest
}

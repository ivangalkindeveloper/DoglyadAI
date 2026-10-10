public import Foundation

/// An interceptor for outgoing requests. An implementation may modify the
/// `URLRequest` before it is sent (for example, add a token header). It lives in
/// an outer module and is passed into `DHttpClient` via init, so the networking
/// layer stays independent of the token source (Firebase and the like).
public protocol DHttpInterceptorProtocol: Sendable {
    func adapt(
        _ urlRequest: URLRequest,
    ) async throws -> URLRequest
}

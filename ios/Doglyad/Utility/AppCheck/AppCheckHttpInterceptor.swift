import DoglyadNetwork
import FirebaseAppCheck
import Foundation

/// Adds a Firebase App Check token header to every outgoing request, confirming
/// the request comes from a genuine app instance (App Attest under the hood).
/// The token is then verified on the backend.
struct AppCheckHttpInterceptor: DHttpInterceptorProtocol {
    func adapt(
        _ urlRequest: URLRequest,
    ) async throws -> URLRequest {
        let token = try await AppCheck.appCheck().token(
            forcingRefresh: false,
        )
        var request = urlRequest
        request.setValue(
            token.token,
            forHTTPHeaderField: DHttpHeader.firebaseAppCheck,
        )
        return request
    }
}

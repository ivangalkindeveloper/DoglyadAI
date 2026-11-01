import Foundation
internal import Alamofire

/// A bridge between the Alamofire-agnostic `DHttpInterceptorProtocol` and
/// Alamofire's `RequestInterceptor`. Applies adapters in order and bridges the
/// async operations to a completion API. A failure stops subsequent adapters.
struct DHttpInterceptorAdapter: RequestInterceptor {
    private let interceptors: [any DHttpInterceptorProtocol]

    init(
        interceptors: [any DHttpInterceptorProtocol],
    ) {
        self.interceptors = interceptors
    }

    func adapt(
        _ urlRequest: URLRequest,
        for _: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void,
    ) {
        Task {
            do {
                var adapted = urlRequest
                for interceptor in interceptors {
                    adapted = try await interceptor.adapt(
                        adapted,
                    )
                }
                completion(
                    .success(
                        adapted,
                    ),
                )
            } catch {
                completion(
                    .failure(
                        error,
                    ),
                )
            }
        }
    }
}

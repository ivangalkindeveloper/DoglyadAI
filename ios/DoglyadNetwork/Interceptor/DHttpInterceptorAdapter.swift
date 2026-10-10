import Foundation
internal import Alamofire

/// A bridge between the Alamofire-agnostic `DHttpInterceptorProtocol` and
/// Alamofire's `RequestInterceptor`. Wraps the async `adapt` into a completion API.
struct DHttpInterceptorAdapter: RequestInterceptor {
    private let interceptor: DHttpInterceptorProtocol

    init(
        interceptor: DHttpInterceptorProtocol,
    ) {
        self.interceptor = interceptor
    }

    func adapt(
        _ urlRequest: URLRequest,
        for _: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void,
    ) {
        Task {
            do {
                let adapted = try await interceptor.adapt(
                    urlRequest,
                )
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

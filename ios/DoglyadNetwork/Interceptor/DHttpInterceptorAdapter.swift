import Foundation
internal import Alamofire

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

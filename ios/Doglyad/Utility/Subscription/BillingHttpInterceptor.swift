import DoglyadDatabase
import DoglyadNetwork
import Foundation

struct BillingHttpInterceptor: DHttpInterceptorProtocol {
    let baseUrl: URL
    let baseVersionPrefix: String
    let securityDatabase: DSecurityDatabaseProtocol

    init(
        baseUrl: URL,
        baseVersionPrefix: String,
        securityDatabase: DSecurityDatabaseProtocol,
    ) {
        self.baseUrl = baseUrl
        self.baseVersionPrefix = baseVersionPrefix
        self.securityDatabase = securityDatabase
    }

    func adapt(
        _ urlRequest: URLRequest,
    ) async throws -> URLRequest {
        var request = urlRequest
        if let url = request.url,
           url.scheme == baseUrl.scheme, url.host == baseUrl.host, url.port == baseUrl.port,
           url.path.hasPrefix(
               baseUrl.path + baseVersionPrefix + "/",
           ),
           let identity = try await securityDatabase.fetchBillingIdentity()
        {
            request.setValue(
                "Bearer " + identity.accessToken,
                forHTTPHeaderField: "Authorization",
            )
        }
        return request
    }
}

public import Foundation

public struct DLocaleInterceptor: DHttpInterceptorProtocol {
    private let preferredLanguageIdentifiers: [String]

    public init(
        preferredLanguageIdentifiers: [String] = Locale.preferredLanguages,
    ) {
        self.preferredLanguageIdentifiers = preferredLanguageIdentifiers
    }

    public func adapt(
        _ urlRequest: URLRequest,
    ) async throws -> URLRequest {
        var request = urlRequest
        request.setValue(
            preferredLanguageIdentifiers.joined(
                separator: ", ",
            ),
            forHTTPHeaderField: DHttpHeader.acceptLanguage,
        )
        return request
    }
}

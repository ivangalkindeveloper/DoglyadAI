import Foundation

final class EnvironmentBase: EnvironmentProtocol {
    let type: EnvironmentType
    let baseUrl: URL
    let baseVersionPrefix: String = "/v1"

    init(
        type: EnvironmentType,
        baseUrl: URL,
    ) {
        self.type = type
        self.baseUrl = baseUrl
    }
}

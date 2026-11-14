import Foundation

struct NetworkConfig: Codable {
    let timeoutIntervalForRequest: TimeInterval
    let timeoutIntervalForResource: TimeInterval

    init(
        timeoutIntervalForRequest: TimeInterval,
        timeoutIntervalForResource: TimeInterval,
    ) {
        self.timeoutIntervalForRequest = timeoutIntervalForRequest
        self.timeoutIntervalForResource = timeoutIntervalForResource
    }
}

extension NetworkConfig {
    static let `default` = NetworkConfig(
        timeoutIntervalForRequest: 300,
        timeoutIntervalForResource: 300,
    )
}

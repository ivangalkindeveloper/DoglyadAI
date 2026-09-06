import Foundation

struct NetworkConfig: Codable {
    let timeoutIntervalForRequest: TimeInterval
    let timeoutIntervalForResource: TimeInterval
}

extension NetworkConfig {
    static let `default` = NetworkConfig(
        timeoutIntervalForRequest: 300,
        timeoutIntervalForResource: 300
    )
}

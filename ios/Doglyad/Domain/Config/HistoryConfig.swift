import Foundation

struct HistoryConfig: Codable {
    let pageSize: Int
}

extension HistoryConfig {
    private static let defaultPageSize = 20

    static let `default` = HistoryConfig(
        pageSize: defaultPageSize
    )
}

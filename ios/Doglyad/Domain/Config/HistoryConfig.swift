import Foundation

struct HistoryConfig: Codable {
    let pageSize: Int

    init(
        pageSize: Int,
    ) {
        self.pageSize = pageSize
    }
}

extension HistoryConfig {
    private static let defaultPageSize = 20
    static let `default` = HistoryConfig(
        pageSize: defaultPageSize,
    )
}

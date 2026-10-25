import Foundation

struct ReadyMadeTemplateListConfig: Codable, Equatable {
    let searchMaxLength: Int
}

extension ReadyMadeTemplateListConfig {
    // Placeholder configuration for previews/tests before server configuration is loaded.
    static let `default` = ReadyMadeTemplateListConfig(
        searchMaxLength: .max,
    )
}

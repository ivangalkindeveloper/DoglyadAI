import Foundation

struct TemplateEditConfig: Codable, Equatable {
    let nameMaxLength: Int
    let contentMaxLength: Int
}

extension TemplateEditConfig {
    // Placeholder configuration for previews/tests before server configuration is loaded.
    static let `default` = TemplateEditConfig(
        nameMaxLength: .max,
        contentMaxLength: .max,
    )
}

import Foundation

struct TemplateAddConfig: Codable, Equatable {
    let nameMaxLength: Int
    let contentMaxLength: Int
}

extension TemplateAddConfig {
    // Placeholder configuration for previews/tests before server configuration is loaded.
    static let `default` = TemplateAddConfig(
        nameMaxLength: .max,
        contentMaxLength: .max,
    )
}

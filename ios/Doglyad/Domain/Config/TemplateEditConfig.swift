import Foundation

struct TemplateEditConfig: Codable, Equatable {
    let nameMaxLength: Int
    let contentMaxLength: Int

    init(
        nameMaxLength: Int,
        contentMaxLength: Int,
    ) {
        self.nameMaxLength = nameMaxLength
        self.contentMaxLength = contentMaxLength
    }
}

extension TemplateEditConfig {
    // Placeholder configuration for previews/tests before server configuration is loaded.
    static let `default` = TemplateEditConfig(
        nameMaxLength: .max,
        contentMaxLength: .max,
    )
}

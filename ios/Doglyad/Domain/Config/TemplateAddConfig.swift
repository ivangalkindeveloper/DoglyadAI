import Foundation

struct TemplateAddConfig: Codable, Equatable {
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

extension TemplateAddConfig {
    // Placeholder configuration for previews/tests before server configuration is loaded.
    static let `default` = TemplateAddConfig(
        nameMaxLength: .max,
        contentMaxLength: .max,
    )
}

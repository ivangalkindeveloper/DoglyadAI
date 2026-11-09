import Foundation

struct WorkSettingsConfig: Codable, Equatable {
    let emailMaxLength: Int
}

extension WorkSettingsConfig {
    // Placeholder configuration for previews/tests before server configuration is loaded.
    static let `default` = WorkSettingsConfig(
        emailMaxLength: .max,
    )
}

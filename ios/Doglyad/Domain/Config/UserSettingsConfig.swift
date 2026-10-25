import Foundation

struct UserSettingsConfig: Codable, Equatable {
    let emailMaxLength: Int
}

extension UserSettingsConfig {
    // Placeholder configuration for previews/tests before server configuration is loaded.
    static let `default` = UserSettingsConfig(
        emailMaxLength: .max,
    )
}

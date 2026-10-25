import Foundation

struct SettingsAIConfig: Codable, Equatable {
    let temperatureMaxLength: Int
    let maxTokensMaxLength: Int
}

extension SettingsAIConfig {
    // Placeholder configuration for previews/tests before server configuration is loaded.
    static let `default` = SettingsAIConfig(
        temperatureMaxLength: .max,
        maxTokensMaxLength: .max,
    )
}

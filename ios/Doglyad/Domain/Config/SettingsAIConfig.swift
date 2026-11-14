import Foundation

struct SettingsAIConfig: Codable, Equatable {
    let temperatureMaxLength: Int
    let maxTokensMaxLength: Int

    init(
        temperatureMaxLength: Int,
        maxTokensMaxLength: Int,
    ) {
        self.temperatureMaxLength = temperatureMaxLength
        self.maxTokensMaxLength = maxTokensMaxLength
    }
}

extension SettingsAIConfig {
    // Placeholder configuration for previews/tests before server configuration is loaded.
    static let `default` = SettingsAIConfig(
        temperatureMaxLength: .max,
        maxTokensMaxLength: .max,
    )
}

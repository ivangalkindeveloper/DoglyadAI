protocol SettingsAIRepositoryProtocol: AnyObject {
    func getSettings() async throws -> SettingsAI?

    func saveSettings(
        _ settings: SettingsAI,
    ) async throws
}

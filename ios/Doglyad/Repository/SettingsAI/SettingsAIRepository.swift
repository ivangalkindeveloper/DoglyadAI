import DoglyadDatabase
import Foundation

final class SettingsAIRepository: SettingsAIRepositoryProtocol {
    private let database: any DDatabaseSettingsAIProtocol

    init(
        database: any DDatabaseSettingsAIProtocol,
    ) {
        self.database = database
    }

    func getSettings() async throws -> SettingsAI? {
        guard let data = try database.getSettingsAIData() else { return nil }
        return try JSONDecoder().decode(
            SettingsAI.self,
            from: data,
        )
    }

    func saveSettings(
        _ settings: SettingsAI,
    ) async throws {
        let data = try JSONEncoder().encode(
            settings,
        )
        database.setSettingsAIData(
            data,
        )
    }
}

import DoglyadDatabase
import Foundation

struct NeuralModelSettings: Codable {
    let selectedNeuralModelId: String?
    let isMarkdown: Bool
    let temperature: Double?
    let maxTokens: Int?
}

extension NeuralModelSettings {
    static func fromDB(
        _ db: NeuralModelSettingsDB,
    ) -> NeuralModelSettings {
        NeuralModelSettings(
            selectedNeuralModelId: db.selectedNeuralModelId,
            isMarkdown: db.isMarkdown,
            temperature: db.temperature,
            maxTokens: db.maxTokens,
        )
    }

    func toDB() -> NeuralModelSettingsDB {
        NeuralModelSettingsDB(
            selectedNeuralModelId: selectedNeuralModelId,
            isMarkdown: isMarkdown,
            temperature: temperature,
            maxTokens: maxTokens,
        )
    }
}

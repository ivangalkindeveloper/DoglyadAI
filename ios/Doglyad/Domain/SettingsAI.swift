import DoglyadDatabase
import Foundation

struct SettingsAI: Codable, Equatable {
    let transcriberType: TranscriberType
    let transcriptParserType: TranscriptParserType
    let selectedNeuralModelId: String?
    let isMarkdown: Bool
    let temperature: Double?
    let maxTokens: Int?

    init(
        transcriberType: TranscriberType = .whisperKit,
        transcriptParserType: TranscriptParserType = .server,
        selectedNeuralModelId: String?,
        isMarkdown: Bool,
        temperature: Double?,
        maxTokens: Int?,
    ) {
        self.transcriberType = transcriberType
        self.transcriptParserType = transcriptParserType
        self.selectedNeuralModelId = selectedNeuralModelId
        self.isMarkdown = isMarkdown
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

extension SettingsAI {
    static func fromDB(
        _ db: SettingsAIDB,
    ) -> SettingsAI {
        SettingsAI(
            transcriberType: db.transcriberType.flatMap {
                TranscriberType(
                    rawValue: $0.trimmingCharacters(
                        in: .whitespacesAndNewlines,
                    ),
                )
            } ?? .whisperKit,
            transcriptParserType: db.transcriptParserType.flatMap {
                TranscriptParserType(
                    rawValue: $0.trimmingCharacters(
                        in: .whitespacesAndNewlines,
                    ),
                )
            } ?? .server,
            selectedNeuralModelId: db.selectedNeuralModelId,
            isMarkdown: db.isMarkdown,
            temperature: db.temperature,
            maxTokens: db.maxTokens,
        )
    }

    func toDB() -> SettingsAIDB {
        SettingsAIDB(
            transcriberType: transcriberType.rawValue,
            transcriptParserType: transcriptParserType.rawValue,
            selectedNeuralModelId: selectedNeuralModelId,
            isMarkdown: isMarkdown,
            temperature: temperature,
            maxTokens: maxTokens,
        )
    }
}

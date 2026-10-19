import Foundation
import SwiftData

@Model
public final class SettingsAIDB {
    public var transcriberType: String?
    public var transcriptParserType: String?
    public var selectedNeuralModelId: String?
    public var isMarkdown: Bool
    public var temperature: Double?
    public var maxTokens: Int?

    public init(
        transcriberType: String? = nil,
        transcriptParserType: String? = nil,
        selectedNeuralModelId: String?,
        isMarkdown: Bool = false,
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

import Foundation

struct UltrasoundExaminationNeuralModelConfig: Codable {
    let temperature: Double
    let maxTokens: Int
    let maxContextTokens: Int
    let prompt: [String: String]
}

extension UltrasoundExaminationNeuralModelConfig {
    static let `default` = UltrasoundExaminationNeuralModelConfig(
        temperature: 0,
        maxTokens: 0,
        maxContextTokens: 0,
        prompt: [:]
    )
}

extension UltrasoundExaminationNeuralModelConfig {
    private static let fallbackPromptLanguageCode = "en"

    func getPrompt(for locale: Locale) -> String? {
        let key = locale.language.languageCode?.identifier ?? Self.fallbackPromptLanguageCode
        return prompt[key] ?? prompt[Self.fallbackPromptLanguageCode]
    }
}

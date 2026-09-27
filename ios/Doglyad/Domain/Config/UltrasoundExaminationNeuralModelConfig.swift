import Foundation

struct UltrasoundExaminationNeuralModelConfig: Codable {
    let temperature: Double
    let maxTokens: Int
    let maxContextTokens: Int
    let prompt: String
}

extension UltrasoundExaminationNeuralModelConfig {
    static let `default` = UltrasoundExaminationNeuralModelConfig(
        temperature: 0,
        maxTokens: 0,
        maxContextTokens: 0,
        prompt: ""
    )
}

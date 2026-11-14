import Foundation

struct UltrasoundNeuralModelConfig: Codable {
    let temperature: Double
    let maxTokens: Int

    init(
        temperature: Double,
        maxTokens: Int,
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

extension UltrasoundNeuralModelConfig {
    static let `default` = UltrasoundNeuralModelConfig(
        temperature: 0.2,
        maxTokens: 512,
    )
}

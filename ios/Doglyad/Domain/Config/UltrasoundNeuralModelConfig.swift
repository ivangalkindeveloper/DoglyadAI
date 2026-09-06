import Foundation

struct UltrasoundNeuralModelConfig: Codable {
    let temperature: Double
    let maxTokens: Int
}

extension UltrasoundNeuralModelConfig {
    static let `default` = UltrasoundNeuralModelConfig(
        temperature: 0.2,
        maxTokens: 512
    )
}

import Foundation

struct UltrasoundExaminationNeuralModelConfig: Codable {
    let temperature: Double
    let maxTokens: Int
    let maxContextTokens: Int
    let prompt: String
    let proposalPrompt: String
}

extension UltrasoundExaminationNeuralModelConfig {
    static let `default` = UltrasoundExaminationNeuralModelConfig(
        temperature: 0,
        maxTokens: 0,
        maxContextTokens: 0,
        prompt: "",
        proposalPrompt: ""
    )
}

extension UltrasoundExaminationNeuralModelConfig {
    private enum CodingKeys: String, CodingKey {
        case temperature, maxTokens, maxContextTokens, prompt, proposalPrompt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        temperature = try values.decode(Double.self, forKey: .temperature)
        maxTokens = try values.decode(Int.self, forKey: .maxTokens)
        maxContextTokens = try values.decode(Int.self, forKey: .maxContextTokens)
        prompt = try values.decode(String.self, forKey: .prompt)
        proposalPrompt = try values.decodeIfPresent(String.self, forKey: .proposalPrompt) ?? ""
    }
}

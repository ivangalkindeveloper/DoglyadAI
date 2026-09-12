struct USExaminationRequest: Codable {
    let neuralModelSettings: NeuralModelSettings
    let examinationData: USExaminationData
    let template: String?
    let includeRecommendations: Bool
}

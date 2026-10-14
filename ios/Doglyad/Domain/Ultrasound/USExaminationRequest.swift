struct USExaminationRequest: Codable {
    let neuralModelSettings: NeuralModelSettings
    let examinationData: USExaminationData
    let template: String?
    let isRecommendationsIncluded: Bool
    let isPhotoRemarks: Bool
    let isDescriptionRemarks: Bool
}

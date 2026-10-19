struct USExaminationRequest: Codable {
    let settingsAI: SettingsAI
    let examinationData: USExaminationData
    let template: String?
    let isRecommendationsIncluded: Bool
    let isPhotoRemarks: Bool
    let isDescriptionRemarks: Bool
}

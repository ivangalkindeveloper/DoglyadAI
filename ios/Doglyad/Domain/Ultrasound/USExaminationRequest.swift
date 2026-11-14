struct USExaminationRequest: Codable {
    let settingsAI: SettingsAI
    let examinationData: USExaminationData
    let template: String?
    let isRecommendationsIncluded: Bool
    let isPhotoRemarks: Bool
    let isDescriptionRemarks: Bool

    init(
        settingsAI: SettingsAI,
        examinationData: USExaminationData,
        template: String?,
        isRecommendationsIncluded: Bool,
        isPhotoRemarks: Bool,
        isDescriptionRemarks: Bool,
    ) {
        self.settingsAI = settingsAI
        self.examinationData = examinationData
        self.template = template
        self.isRecommendationsIncluded = isRecommendationsIncluded
        self.isPhotoRemarks = isPhotoRemarks
        self.isDescriptionRemarks = isDescriptionRemarks
    }
}

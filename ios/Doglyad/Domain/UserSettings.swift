import Foundation

struct UserSettings {
    let email: String?
    let isNeedPatientConsent: Bool
    let isRecommendationsIncluded: Bool
    let isPhotoRemarks: Bool
    let isDescriptionRemarks: Bool
    let isRemarksVisible: Bool
    static let initial = UserSettings(
        email: nil,
        isRecommendationsIncluded: true,
        isPhotoRemarks: true,
        isDescriptionRemarks: true,
        isRemarksVisible: true,
    )

    init(
        email: String?,
        isNeedPatientConsent: Bool = true,
        isRecommendationsIncluded: Bool,
        isPhotoRemarks: Bool,
        isDescriptionRemarks: Bool,
        isRemarksVisible: Bool,
    ) {
        self.email = email
        self.isNeedPatientConsent = isNeedPatientConsent
        self.isRecommendationsIncluded = isRecommendationsIncluded
        self.isPhotoRemarks = isPhotoRemarks
        self.isDescriptionRemarks = isDescriptionRemarks
        self.isRemarksVisible = isRemarksVisible
    }
}

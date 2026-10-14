import Foundation

struct UserSettings {
    let email: String?
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
}

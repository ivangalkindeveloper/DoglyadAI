import Foundation

public protocol DDatabaseUserSettingsProtocol: AnyObject {
    func getIsPhotoRemarks() -> Bool
    func setIsPhotoRemarks(
        isEnabled: Bool,
    )
    func getIsDescriptionRemarks() -> Bool
    func setIsDescriptionRemarks(
        isEnabled: Bool,
    )
    func getIsRemarksVisible() -> Bool
    func setIsRemarksVisible(
        isVisible: Bool,
    )
    func getUserEmail() -> String?

    func setUserEmail(
        value: String?,
    )

    func getIsRecommendationsIncluded() -> Bool

    func setIsRecommendationsIncluded(
        isIncluded: Bool,
    )
}

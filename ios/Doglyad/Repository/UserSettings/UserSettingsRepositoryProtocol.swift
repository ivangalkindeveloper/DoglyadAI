import Foundation

protocol UserSettingsRepositoryProtocol: AnyObject {
    func getIsPhotoRemarks() -> Bool
    func setIsPhotoRemarks(
        _ value: Bool,
    )
    func getIsDescriptionRemarks() -> Bool
    func setIsDescriptionRemarks(
        _ value: Bool,
    )
    func getIsRemarksVisible() -> Bool
    func setIsRemarksVisible(
        _ value: Bool,
    )
    func getUserEmail() -> String?

    func setUserEmail(
        _ email: String?,
    )

    func getIncludeRecommendations() -> Bool

    func setIncludeRecommendations(
        _ value: Bool,
    )

    func sendEmail(
        email: ReportEmail,
    ) async throws
}

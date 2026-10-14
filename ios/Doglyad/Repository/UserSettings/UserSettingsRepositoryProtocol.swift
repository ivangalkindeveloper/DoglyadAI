import Foundation

protocol UserSettingsRepositoryProtocol: AnyObject {
    func getIsPhotoRemarks() async throws -> Bool
    func setIsPhotoRemarks(
        _ isEnabled: Bool,
    ) async throws

    func getIsDescriptionRemarks() async throws -> Bool
    func setIsDescriptionRemarks(
        _ isEnabled: Bool,
    ) async throws

    func getIsRemarksVisible() async throws -> Bool
    func setIsRemarksVisible(
        _ isVisible: Bool,
    ) async throws

    func getUserEmail() async throws -> String?

    func setUserEmail(
        _ email: String?,
    ) async throws

    func getIsRecommendationsIncluded() async throws -> Bool

    func setIsRecommendationsIncluded(
        _ isIncluded: Bool,
    ) async throws

    func sendEmail(
        email: ReportEmail,
    ) async throws
}

import Foundation

protocol UserSettingsRepositoryProtocol: AnyObject {
    func getUserEmail() -> String?

    func setUserEmail(_ email: String?)

    func getIncludeRecommendations() -> Bool

    func setIncludeRecommendations(_ value: Bool)

    func sendEmail(
        email: ReportEmail
    ) async throws
}

import DoglyadDatabase
import DoglyadNetwork

final class UserSettingsRepository: UserSettingsRepositoryProtocol {
    let database: DDatabaseProtocol
    let httpClient: DHttpClientProtocol

    init(
        database: DDatabaseProtocol,
        httpClient: DHttpClientProtocol,
    ) {
        self.database = database
        self.httpClient = httpClient
    }
}

extension UserSettingsRepository {
    func getIsPhotoRemarks() async throws -> Bool { database.getIsPhotoRemarks() }

    func setIsPhotoRemarks(
        _ isEnabled: Bool,
    ) async throws { database.setIsPhotoRemarks(
        isEnabled: isEnabled,
    ) }

    func getIsDescriptionRemarks() async throws -> Bool { database.getIsDescriptionRemarks() }

    func setIsDescriptionRemarks(
        _ isEnabled: Bool,
    ) async throws { database.setIsDescriptionRemarks(
        isEnabled: isEnabled,
    ) }

    func getIsRemarksVisible() async throws -> Bool { database.getIsRemarksVisible() }

    func setIsRemarksVisible(
        _ isVisible: Bool,
    ) async throws { database.setIsRemarksVisible(
        isVisible: isVisible,
    ) }

    func getUserEmail() async throws -> String? {
        database.getUserEmail()
    }

    func setUserEmail(
        _ email: String?,
    ) async throws {
        database.setUserEmail(
            value: email,
        )
    }

    func getIsRecommendationsIncluded() async throws -> Bool {
        database.getIsRecommendationsIncluded()
    }

    func setIsRecommendationsIncluded(
        _ isIncluded: Bool,
    ) async throws {
        database.setIsRecommendationsIncluded(
            isIncluded: isIncluded,
        )
    }
}

extension UserSettingsRepository {
    static let sendEmailEndpoint = "/send_report_email"

    func sendEmail(
        email: ReportEmail,
    ) async throws {
        try await httpClient.post(
            endPoint: Self.sendEmailEndpoint,
            body: email,
            headers: nil,
            encoderUserInfo: nil,
        )
    }
}

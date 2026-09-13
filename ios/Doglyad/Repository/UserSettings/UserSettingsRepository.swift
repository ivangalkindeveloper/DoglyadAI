import DoglyadDatabase
import DoglyadNetwork

final class UserSettingsRepository: UserSettingsRepositoryProtocol {
    let database: DDatabaseProtocol
    let httpClient: DHttpClientProtocol

    init(
        database: DDatabaseProtocol,
        httpClient: DHttpClientProtocol
    ) {
        self.database = database
        self.httpClient = httpClient
    }
}

extension UserSettingsRepository {
    func getUserEmail() -> String? {
        database.getUserEmail()
    }

    func setUserEmail(_ email: String?) {
        database.setUserEmail(value: email)
    }

    func getIncludeRecommendations() -> Bool {
        database.getIncludeRecommendations()
    }

    func setIncludeRecommendations(_ value: Bool) {
        database.setIncludeRecommendations(value: value)
    }
}

extension UserSettingsRepository {
    static let sendEmailEndpoint = "/send_report_email"

    func sendEmail(
        email: ReportEmail
    ) async throws {
        try await httpClient.post(
            endPoint: Self.sendEmailEndpoint,
            body: email,
            headers: nil,
            encoderUserInfo: nil
        )
    }
}

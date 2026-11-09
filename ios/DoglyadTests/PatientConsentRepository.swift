@testable import Doglyad
import Foundation

@MainActor
final class PatientConsentRepository: UserSettingsRepositoryProtocol {
    let wrapped: UserSettingsRepositoryProtocol
    var isNeedPatientConsent = true
    var onRead: (() async throws -> Bool)?
    var onWrite: ((Bool) async throws -> Void)?
    private(set) var readCount = 0
    private(set) var writes: [Bool] = []

    init(
        wrapped: UserSettingsRepositoryProtocol,
    ) {
        self.wrapped = wrapped
    }

    func getIsPhotoRemarks() async throws -> Bool {
        try await wrapped.getIsPhotoRemarks()
    }

    func setIsPhotoRemarks(
        _ isEnabled: Bool,
    ) async throws {
        try await wrapped.setIsPhotoRemarks(
            isEnabled,
        )
    }

    func getIsDescriptionRemarks() async throws -> Bool {
        try await wrapped.getIsDescriptionRemarks()
    }

    func setIsDescriptionRemarks(
        _ isEnabled: Bool,
    ) async throws {
        try await wrapped.setIsDescriptionRemarks(
            isEnabled,
        )
    }

    func getIsRemarksVisible() async throws -> Bool {
        try await wrapped.getIsRemarksVisible()
    }

    func setIsRemarksVisible(
        _ isVisible: Bool,
    ) async throws {
        try await wrapped.setIsRemarksVisible(
            isVisible,
        )
    }

    func getUserEmail() async throws -> String? {
        try await wrapped.getUserEmail()
    }

    func setUserEmail(
        _ email: String?,
    ) async throws {
        try await wrapped.setUserEmail(
            email,
        )
    }

    func getIsNeedPatientConsent() async throws -> Bool {
        readCount += 1
        if let onRead {
            return try await onRead()
        }
        return isNeedPatientConsent
    }

    func setIsNeedPatientConsent(
        _ isNeedPatientConsent: Bool,
    ) async throws {
        writes.append(
            isNeedPatientConsent,
        )
        try await onWrite?(
            isNeedPatientConsent,
        )
        self.isNeedPatientConsent = isNeedPatientConsent
    }

    func getIsRecommendationsIncluded() async throws -> Bool {
        try await wrapped.getIsRecommendationsIncluded()
    }

    func setIsRecommendationsIncluded(
        _ isIncluded: Bool,
    ) async throws {
        try await wrapped.setIsRecommendationsIncluded(
            isIncluded,
        )
    }

    func sendEmail(
        email: ReportEmail,
    ) async throws {
        try await wrapped.sendEmail(
            email: email,
        )
    }
}

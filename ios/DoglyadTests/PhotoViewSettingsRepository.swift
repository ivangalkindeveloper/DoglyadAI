@testable import Doglyad
import Foundation

@MainActor
final class PhotoViewSettingsRepository: UserSettingsRepositoryProtocol {
    let wrapped: UserSettingsRepositoryProtocol
    var isRemarksVisible = true
    var onRead: (() async throws -> Bool)?
    var onWrite: ((Bool) async throws -> Void)?

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
        try await onRead?() ?? isRemarksVisible
    }

    func setIsRemarksVisible(
        _ isVisible: Bool,
    ) async throws {
        try await onWrite?(
            isVisible,
        )
        isRemarksVisible = isVisible
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
        try await wrapped.getIsNeedPatientConsent()
    }

    func setIsNeedPatientConsent(
        _ isNeedPatientConsent: Bool,
    ) async throws {
        try await wrapped.setIsNeedPatientConsent(
            isNeedPatientConsent,
        )
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

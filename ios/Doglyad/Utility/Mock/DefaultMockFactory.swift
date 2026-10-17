import Foundation

final class DefaultMockFactory: MockFactoryProtocol {
    func fillPatientComplaints(
        l10n: L10N,
    ) -> String {
        l10n.text(
            .scanDevelopmentPatientComplaintsDescription,
        )
    }

    func fillExaminationDescription(
        l10n: L10N,
    ) -> String {
        l10n.text(
            .scanDevelopmentExaminationDescription,
        )
    }
}

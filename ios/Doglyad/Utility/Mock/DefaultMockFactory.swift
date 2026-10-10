import Foundation

final class DefaultMockFactory: MockFactory {
    func fillPatientComplaints(
        l10n: L10N,
    ) -> String {
        l10n.text(
            .mockPatientComplaints,
        )
    }

    func fillExaminationDescription(
        l10n: L10N,
    ) -> String {
        l10n.text(
            .mockExaminationDescription,
        )
    }
}

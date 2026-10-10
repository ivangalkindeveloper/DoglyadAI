import Foundation

protocol MockFactory: AnyObject {
    func fillPatientComplaints(
        l10n: L10N,
    ) -> String

    func fillExaminationDescription(
        l10n: L10N,
    ) -> String
}

import Foundation

protocol MockFactoryProtocol: AnyObject {
    var examinationTypeId: String {
        get
    }

    func fillPatientComplaints(
        l10n: L10N,
    ) -> String

    func fillExaminationDescription(
        l10n: L10N,
    ) -> String
}

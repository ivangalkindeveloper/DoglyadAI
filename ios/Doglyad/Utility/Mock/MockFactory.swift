import Foundation

protocol MockFactory: AnyObject {
    func fillPatientComplaints(
        for locale: Locale
    ) -> String

    func fillExaminationDescription(
        for locale: Locale
    ) -> String
}

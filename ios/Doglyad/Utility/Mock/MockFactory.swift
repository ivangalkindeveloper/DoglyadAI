import Foundation

protocol MockFactory: AnyObject {
    func fillPatientComplaint(
        for locale: Locale
    ) -> String

    func fillExaminationDescription(
        for locale: Locale
    ) -> String
}

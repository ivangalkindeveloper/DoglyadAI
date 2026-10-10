import Foundation

final class DefaultMockFactory: MockFactory {
    func fillPatientComplaints(
        for locale: Locale,
    ) -> String {
        String(
            localized: "mockPatientComplaints",
            locale: locale,
        )
    }

    func fillExaminationDescription(
        for locale: Locale,
    ) -> String {
        String(
            localized: "mockExaminationDescription",
            locale: locale,
        )
    }
}

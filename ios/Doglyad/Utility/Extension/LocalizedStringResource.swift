import Foundation

extension LocalizedStringResource {
    static func forExaminationTypeById(
        types: [String: USExaminationType],
        id: String,
    ) -> LocalizedStringResource {
        types[
            id,
        ]?.localizedTitle ?? LocalizedStringResource(
            "",
        )
    }

    static func forGender(
        _ gender: PatientGender,
    ) -> LocalizedStringResource {
        switch gender {
        case PatientGender.male:
            .scanGenderMaleLabel
        case PatientGender.female:
            .scanGenderFemaleLabel
        }
    }
}

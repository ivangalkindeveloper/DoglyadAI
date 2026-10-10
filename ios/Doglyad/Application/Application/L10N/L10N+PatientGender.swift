import Foundation

extension L10N {
    func forGender(
        _ gender: PatientGender,
    ) -> LocalizedStringResource {
        switch gender {
        case PatientGender.male:
            self[
                .scanGenderMaleLabel,
            ]
        case PatientGender.female:
            self[
                .scanGenderFemaleLabel,
            ]
        }
    }
}

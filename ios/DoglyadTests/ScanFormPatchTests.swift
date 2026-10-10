@testable import Doglyad
import DoglyadNeuralModel
import Foundation
import Testing

struct ScanFormPatchTests {
    @Test(
        "Only confirmed fields replace existing form values",
    )
    func appliesSelectedFields() throws {
        let form = fixture()
        let selected = [
            DNeuralUltrasoundVoiceFieldProposal(
                id: .examinationNumber,
                value: .text(
                    "007",
                ),
                sourceQuote: "номер 007",
            ),
            DNeuralUltrasoundVoiceFieldProposal(
                id: .patientComplaints,
                value: .text(
                    "Боль справа",
                ),
                sourceQuote: "боль справа",
            ),
        ]
        let updated = try #require(
            ScanFormPatch.apply(
                selected,
                to: form,
            ),
        )
        #expect(
            updated.examinationNumber == "007",
        )
        #expect(
            updated.patientComplaints == "Боль справа",
        )
        #expect(
            updated.patientName == form.patientName,
        )
        #expect(
            updated.examinationDescription == form.examinationDescription,
        )
        #expect(
            updated.patientDateOfBirth == form.patientDateOfBirth,
        )
    }

    @Test(
        "A mistyped or duplicate proposal does not produce a partial patch",
    )
    func rejectsInvalidPatch() {
        let form = fixture()
        let valid = DNeuralUltrasoundVoiceFieldProposal(
            id: .patientName,
            value: .text(
                "Пётр",
            ),
            sourceQuote: "Пётр",
        )
        let invalid = DNeuralUltrasoundVoiceFieldProposal(
            id: .patientGender,
            value: .text(
                "male",
            ),
            sourceQuote: "мужчина",
        )
        #expect(
            ScanFormPatch.apply(
                [valid, invalid],
                to: form,
            ) == nil,
        )
        #expect(
            ScanFormPatch.apply(
                [valid, valid],
                to: form,
            ) == nil,
        )
        #expect(
            form.patientName == "Иван",
        )
    }

    private func fixture() -> USExaminationDraftForm {
        USExaminationDraftForm(
            examinationNumber: "3",
            patientName: "Иван",
            patientGender: .male,
            patientDateOfBirth: Date(
                timeIntervalSince1970: 0,
            ),
            patientHeightCM: "180",
            patientWeightKG: "75",
            patientComplaints: "Нет жалоб",
            examinationDescription: "Старое описание",
        )
    }
}

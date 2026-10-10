@testable import DoglyadNeuralModel
import Foundation
import Testing

struct DictationProfileEvidenceTests {
    @Test(
        "Patient profile alone cannot supply an ultrasound description",
        arguments: [
            ("Patient, Claire Wilson. Date of birth, November 24, 1996. Height, 169 centimeters. Weight, 58.2 kilograms. Complaints, no complaints.", "en_US"),
            ("Weight. 58.2 kilograms. Patient. Claire Wilson. Complaints. No complaints. Date of birth. November 24, 1996. Height. 169 centimeters.", "en_US"),
            ("Пациент – Дарья Морозова. Дата рождения – 24 ноября 1996 года. Рост – 169 см. Вес – 58,2 кг. Жалобы – жалоб нет.", "ru_RU"),
        ],
    )
    func rejectsProfileDescription(
        example: (String, String),
    ) throws {
        let (text, locale) = example
        #expect(
            DNeuralUltrasoundDictationProfileEvidence.containsOnlyProfile(
                text,
                locale: Locale(
                    identifier: locale,
                ),
                localization: VoiceLocalizationTestSupport.dictation(
                    locale: Locale(
                        identifier: locale,
                    ),
                ),
            ),
        )
        let request = DNeuralUltrasoundDictationParseRequest(
            text: text,
            examinationTypeId: "thyroidGland",
            examinationTypeTitle: "Unit-test examination",
            locale: Locale(
                identifier: locale,
            ),
            allowedFields: [.patientHeightCM, .examinationDescription],
            localization: VoiceLocalizationTestSupport.dictation(
                locale: Locale(
                    identifier: locale,
                ),
            ),
        )
        let generated = DNeuralUltrasoundProposalGenerationResponse(
            proposals: [
                .init(
                    fieldId: .examinationDescription,
                    value: text,
                    sourceQuote: text,
                ),
                .init(
                    fieldId: .patientHeightCM,
                    value: "169",
                    sourceQuote: text,
                ),
            ],
            unmappedFindings: [],
        )
        let result = try DNeuralUltrasoundProposalProcessor.validate(
            generated: generated,
            request: request,
        )
        #expect(
            result.proposals.map(
                \.id,
            ) == [.patientHeightCM],
        )
        #expect(
            result.rejectedFieldIds == [.examinationDescription],
        )
        #expect(
            result.unmappedFindings.contains(
                text,
            ),
        )
    }

    @Test(
        "An unfamiliar or clinical sentence prevents a profile-only rejection",
        arguments: [
            "Patient, Claire Wilson. Liver normal.",
            "Patient, Claire Wilson. No thyroid nodules.",
            "Patient, Claire Wilson. Ultrasound shows a 4 mm cyst.",
            "Patient, Claire Wilson. Complaints, pain in the neck.",
            "Пациент – Дарья Морозова. Правая почка 110 мм.",
            "Patient reports pain when walking.",
            "Right kidney 109 mm. No collecting system dilatation.",
        ],
    )
    func preservesClinicalContent(
        text: String,
    ) {
        #expect(
            !DNeuralUltrasoundDictationProfileEvidence.containsOnlyProfile(
                text,
                locale: Locale(
                    identifier: "en_US",
                ),
                localization: VoiceLocalizationTestSupport.dictation(
                    locale: Locale(
                        identifier: "en_US",
                    ),
                ),
            ),
        )
    }
}

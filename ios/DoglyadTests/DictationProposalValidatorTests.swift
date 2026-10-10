@testable import DoglyadNeuralModel
import Foundation
import Testing

struct DictationProposalValidatorTests {
    @Test(
        "A changed side is flagged in Russian",
    )
    func changedSide() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Левая почка 12 мм",
            quote: "Правая почка 12 мм",
        ).warnings
        #expect(
            warnings.contains(
                .sideMismatch,
            ),
        )
    }

    @Test(
        "A lost negation is flagged in English",
    )
    func lostNegation() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Free fluid",
            quote: "No free fluid",
            locale: "en_US",
        ).warnings
        #expect(
            warnings.contains(
                .negationMismatch,
            ),
        )
    }

    @Test(
        "Changed negation scope with the same word count is still flagged",
    )
    func switchedNegationScope() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Aortic valve without regurgitation. Mitral valve with regurgitation.",
            quote: "Mitral valve without regurgitation. Aortic valve with regurgitation.",
            locale: "en_US",
        ).warnings
        #expect(
            warnings.contains(
                .textChanged,
            ),
        )
    }

    @Test(
        "A discourse correction marked by punctuation needs review",
    )
    func discourseCorrection() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "No lesions present",
            quote: "No, lesions present",
            locale: "en_US",
        ).warnings
        #expect(
            warnings.contains(
                .ambiguousDictation,
            ),
        )
    }

    @Test(
        "Changed numbers and units are flagged independently",
    )
    func changedMeasurement() throws {
        let changedNumber = try proposal(
            field: .examinationDescription,
            value: "Right kidney 14 mm",
            quote: "Right kidney 12 mm",
            locale: "en_US",
        )
        let changedUnit = try proposal(
            field: .examinationDescription,
            value: "Right kidney 12 cm",
            quote: "Right kidney 12 mm",
            locale: "en_US",
        )
        #expect(
            changedNumber.warnings.contains(
                .numberMismatch,
            ),
        )
        #expect(
            !changedNumber.warnings.contains(
                .unitMismatch,
            ),
        )
        #expect(
            changedUnit.warnings.contains(
                .unitMismatch,
            ),
        )
    }

    @Test(
        "Swapped number-unit pairs are flagged",
    )
    func swappedUnits() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "12 cm and 5 mm",
            quote: "12 mm and 5 cm",
            locale: "en_US",
        ).warnings
        #expect(
            warnings.contains(
                .unitMismatch,
            ),
        )
    }

    @Test(
        "A correction outside the exact quote is still flagged",
    )
    func nearbyCorrection() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "15 mm",
            quote: "15 mm",
            dictation: "Right kidney 12, no, 15 mm.",
            locale: "en_US",
        ).warnings
        #expect(
            warnings.contains(
                .ambiguousDictation,
            ),
        )
    }

    @Test(
        "Spoken-number corrections need review even when copied literally",
    )
    func spokenNumberCorrection() throws {
        let english = try proposal(
            field: .examinationDescription,
            value: "middle cerebral artery: sixty five, no, sixty two centimeters per second",
            quote: "middle cerebral artery: sixty five, no, sixty two centimeters per second",
            locale: "en_US",
        )
        let russian = try proposal(
            field: .examinationDescription,
            value: "общая сонная артерия: восемь, нет, пять миллиметров",
            quote: "общая сонная артерия: восемь, нет, пять миллиметров",
        )
        #expect(
            english.warnings.contains(
                .ambiguousDictation,
            ),
        )
        #expect(
            russian.warnings.contains(
                .ambiguousDictation,
            ),
        )
    }

    @Test(
        "A quote omitting the rest of an ultrasound observation needs review",
    )
    func incompleteObservationQuote() throws {
        let partial = try proposal(
            field: .examinationDescription,
            value: "mucosal thickening: three millimeters",
            quote: "On ultrasound, mucosal thickening: three millimeters",
            dictation: "On ultrasound, mucosal thickening: three millimeters. No additional abnormality.",
            locale: "en_US",
        )
        let complete = try proposal(
            field: .examinationDescription,
            value: "mucosal thickening: three millimeters. No additional abnormality.",
            quote: "On ultrasound, mucosal thickening: three millimeters. No additional abnormality.",
            locale: "en_US",
        )
        #expect(
            partial.warnings.contains(
                .ambiguousDictation,
            ),
        )
        #expect(
            !complete.warnings.contains(
                .ambiguousDictation,
            ),
        )
    }

    @Test(
        "A complaint quoted as an ultrasound finding needs review",
    )
    func complaintAsObservation() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "отёчность",
            quote: "отёчность",
            dictation: "На УЗИ остаточная моча 24 мл. Сообщает: отёчность, вес 66 кг",
        ).warnings
        #expect(
            warnings.contains(
                .ambiguousDictation,
            ),
        )
    }

    @Test(
        "A complaint quote containing a measurement requires review",
    )
    func observationAsComplaint() throws {
        let warnings = try proposal(
            field: .patientComplaints,
            value: "swelling ultrasound right ventricle 47 mm",
            quote: "they report swelling ultrasound right ventricle 47 mm",
            locale: "en_US",
        ).warnings
        #expect(
            warnings.contains(
                .ambiguousDictation,
            ),
        )
    }

    @Test(
        "A correction in the next dictated clause flags the earlier quote",
    )
    func followingCorrection() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Правая почка 12 мм",
            quote: "Правая почка 12 мм",
            dictation: "Правая почка 12 мм; нет, левая почка 14 мм",
        ).warnings
        #expect(
            warnings.contains(
                .ambiguousDictation,
            ),
        )
    }

    @Test(
        "A following no-complaints field is not treated as a correction",
    )
    func followingNegativeField() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Right kidney 12 mm",
            quote: "Right kidney 12 mm",
            dictation: "Right kidney 12 mm; no complaints",
            locale: "en_US",
        ).warnings
        #expect(
            warnings.isEmpty,
        )
    }

    @Test(
        "A conflicting side outside the quoted excerpt is flagged",
    )
    func sideConflictInClause() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Правая почка 12 мм",
            quote: "Правая почка 12 мм",
            dictation: "Правая почка 12 мм, не левая",
        ).warnings
        #expect(
            warnings.contains(
                .ambiguousDictation,
            ),
        )
    }

    @Test(
        "A literal clinical description has no detected conflict",
    )
    func literalDescription() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Правая почка 12 мм. Конкрементов нет.",
            quote: "Описание: Правая почка 12 мм. Конкрементов нет.",
        ).warnings
        #expect(
            warnings.isEmpty,
        )
    }

    @Test(
        "Meters are converted to centimeters when the quoted unit is explicit",
    )
    func heightConversion() throws {
        let correct = try proposal(
            field: .patientHeightCM,
            value: "174",
            quote: "Рост 1,74 м",
        )
        let wrongUnit = try validatorWarnings(
            field: .patientHeightCM,
            value: "174",
            quote: "Рост 174 мм",
        )
        #expect(
            correct.warnings.isEmpty,
        )
        #expect(
            wrongUnit.contains(
                .unitMismatch,
            ),
        )
    }

    @Test(
        "Date, gender and leading-zero identifier require explicit support",
    )
    func structuredValues() throws {
        let incompleteDate = try validatorWarnings(
            field: .patientDateOfBirth,
            value: "1980-01-01",
            quote: "Дата рождения 1980 год",
        )
        let inferredGender = try validatorWarnings(
            field: .patientGender,
            value: "female",
            quote: "Пациент Иван",
        )
        let numberRequest = DNeuralUltrasoundDictationParseRequest(
            text: "Номер исследования 007",
            examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
            examinationTypeTitle: "Unit-test examination",
            locale: Locale(
                identifier: "ru_RU",
            ),
            allowedFields: [.examinationNumber],
            localization: VoiceLocalizationTestSupport.dictation(
                locale: Locale(
                    identifier: "ru_RU",
                ),
            ),
        )
        let changedNumberWarnings = DNeuralUltrasoundDictationProposalValidator.warnings(
            fieldId: .examinationNumber,
            value: .text(
                "7",
            ),
            sourceQuote: "Номер исследования 007",
            request: numberRequest,
        )
        let completeDate = try proposal(
            field: .patientDateOfBirth,
            value: "1990-01-02",
            quote: "Дата рождения 02.01.1990",
        )
        let explicitGender = try proposal(
            field: .patientGender,
            value: "female",
            quote: "Пол женский",
        )
        #expect(
            incompleteDate.contains(
                .dateUnverified,
            ),
        )
        #expect(
            inferredGender.contains(
                .genderUnverified,
            ),
        )
        #expect(
            changedNumberWarnings.contains(
                .identifierMismatch,
            ),
        )
        #expect(
            completeDate.warnings.isEmpty,
        )
        #expect(
            explicitGender.warnings.isEmpty,
        )
    }

    @Test(
        "Spoken identifier digits keep leading zeros and require the study cue",
    )
    func spokenIdentifier() throws {
        let english = try validatorWarnings(
            field: .examinationNumber,
            value: "026",
            quote: "This is study zero two six.",
            locale: "en_US",
        )
        let russian = try validatorWarnings(
            field: .examinationNumber,
            value: "091",
            quote: "Это исследование номер ноль девять один.",
        )
        let wrong = try validatorWarnings(
            field: .examinationNumber,
            value: "26",
            quote: "This is study zero two six.",
            locale: "en_US",
        )
        #expect(
            !english.contains(
                .identifierMismatch,
            ),
        )
        #expect(
            !russian.contains(
                .identifierMismatch,
            ),
        )
        #expect(
            wrong.contains(
                .identifierMismatch,
            ),
        )
    }

    @Test(
        "Spoken cardinal measurements support their normalized numeric values",
    )
    func spokenMeasurements() throws {
        let height = try validatorWarnings(
            field: .patientHeightCM,
            value: "182",
            quote: "one hundred eighty two centimeters tall",
            locale: "en_US",
        )
        let weight = try validatorWarnings(
            field: .patientWeightKG,
            value: "66",
            quote: "вес шестьдесят шесть килограммов",
        )
        let wrong = try validatorWarnings(
            field: .patientWeightKG,
            value: "60",
            quote: "вес шестьдесят шесть килограммов",
        )
        #expect(
            !height.contains(
                .numberMismatch,
            ),
        )
        #expect(
            !weight.contains(
                .numberMismatch,
            ),
        )
        #expect(
            wrong.contains(
                .numberMismatch,
            ),
        )
    }

    @Test(
        "A spoken month date is verified against the proposed date",
    )
    func spokenMonthDate() throws {
        let matching = try proposal(
            field: .patientDateOfBirth,
            value: "1974-10-23",
            quote: "Date of birth October 23, 1974",
            locale: "en_US",
        )
        let different = try proposal(
            field: .patientDateOfBirth,
            value: "1974-10-24",
            quote: "Date of birth October 23, 1974",
            locale: "en_US",
        )
        #expect(
            !matching.warnings.contains(
                .dateUnverified,
            ),
        )
        #expect(
            different.warnings.contains(
                .dateUnverified,
            ),
        )
    }

    @Test(
        "Woman and man explicitly support a gender proposal",
    )
    func spokenGenderNouns() throws {
        let woman = try proposal(
            field: .patientGender,
            value: "female",
            quote: "A woman",
            locale: "en_US",
        )
        let man = try proposal(
            field: .patientGender,
            value: "male",
            quote: "A man",
            locale: "en_US",
        )
        #expect(
            woman.warnings.isEmpty,
        )
        #expect(
            man.warnings.isEmpty,
        )
    }

    @Test(
        "An unrelated number cannot silently become the examination number",
    )
    func unrelatedNumber() throws {
        let englishQuote = "Insurance number: 007."
        let russianQuote = "Номер полиса: 007."
        let englishRequest = DNeuralUltrasoundDictationParseRequest(
            text: englishQuote,
            examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
            examinationTypeTitle: "Unit-test examination",
            locale: Locale(
                identifier: "en_US",
            ),
            allowedFields: [.examinationNumber],
            localization: VoiceLocalizationTestSupport.dictation(
                locale: Locale(
                    identifier: "en_US",
                ),
            ),
        )
        let russianRequest = DNeuralUltrasoundDictationParseRequest(
            text: russianQuote,
            examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
            examinationTypeTitle: "Unit-test examination",
            locale: Locale(
                identifier: "ru_RU",
            ),
            allowedFields: [.examinationNumber],
            localization: VoiceLocalizationTestSupport.dictation(
                locale: Locale(
                    identifier: "ru_RU",
                ),
            ),
        )
        let english = DNeuralUltrasoundDictationProposalValidator.warnings(
            fieldId: .examinationNumber,
            value: .text(
                "007",
            ),
            sourceQuote: englishQuote,
            request: englishRequest,
        )
        let russian = DNeuralUltrasoundDictationProposalValidator.warnings(
            fieldId: .examinationNumber,
            value: .text(
                "007",
            ),
            sourceQuote: russianQuote,
            request: russianRequest,
        )
        let examination = try proposal(
            field: .examinationNumber,
            value: "007",
            quote: "Номер исследования: 007.",
        )
        #expect(
            english.contains(
                .identifierMismatch,
            ),
        )
        #expect(
            russian.contains(
                .identifierMismatch,
            ),
        )
        #expect(
            examination.warnings.isEmpty,
        )
    }

    @Test(
        "Labelled alphanumeric identifiers keep every letter and leading zero",
    )
    func alphanumericIdentifier() throws {
        let english = try proposal(
            field: .examinationNumber,
            value: "HIP-0064",
            quote: "Study number HIP-0064",
            locale: "en_US",
        )
        let russian = try proposal(
            field: .examinationNumber,
            value: "УЗИ-0041",
            quote: "Номер исследования: УЗИ-0041",
        )
        let shortened = try validatorWarnings(
            field: .examinationNumber,
            value: "64",
            quote: "Study number HIP-0064",
            locale: "en_US",
        )
        let measurement = try validatorWarnings(
            field: .examinationNumber,
            value: "12",
            quote: "Study 12 mm",
            locale: "en_US",
        )
        #expect(
            english.warnings.isEmpty,
        )
        #expect(
            russian.warnings.isEmpty,
        )
        #expect(
            shortened.contains(
                .identifierMismatch,
            ),
        )
        #expect(
            measurement.contains(
                .identifierMismatch,
            ),
        )
    }

    @Test(
        "Unrelated bilateral findings do not make patient metadata ambiguous",
    )
    func metadataContextIsBounded() throws {
        let text = "Patient: Sarah Bennett. Height 168 cm. Weight 64.1 kg. Date of birth 02.01.1990. "
            + "On ultrasound, right kidney 110 mm and left kidney 112 mm."
        let height = try proposal(
            field: .patientHeightCM,
            value: "168",
            quote: "Height 168 cm",
            dictation: text,
            locale: "en_US",
        )
        let weight = try proposal(
            field: .patientWeightKG,
            value: "64.1",
            quote: "Weight 64.1 kg",
            dictation: text,
            locale: "en_US",
        )
        let birthday = try proposal(
            field: .patientDateOfBirth,
            value: "1990-01-02",
            quote: "Date of birth 02.01.1990",
            dictation: text,
            locale: "en_US",
        )
        #expect(
            height.warnings.isEmpty,
        )
        #expect(
            weight.warnings.isEmpty,
        )
        #expect(
            birthday.warnings.isEmpty,
        )
    }

    @Test(
        "A fetal cue outside a narrow model quote rejects the patient's gender",
    )
    func fetalGenderIsRejected() throws {
        for (code, text, quote) in [
            ("en_US", "On ultrasound, fetal sex is female. Fluid is normal.", "sex is female"),
            ("ru_RU", "На УЗИ пол плода женский. Воды в норме.", "женский"),
        ] {
            let request = DNeuralUltrasoundDictationParseRequest(
                text: text,
                examinationTypeId: "pregnancySecondTrimester",
                examinationTypeTitle: "Unit-test examination",
                locale: Locale(
                    identifier: code,
                ),
                allowedFields: [.patientGender],
                localization: VoiceLocalizationTestSupport.dictation(
                    locale: Locale(
                        identifier: code,
                    ),
                ),
            )
            let generated = DNeuralUltrasoundProposalGenerationResponse(
                proposals: [DNeuralUltrasoundProposalGenerationItem(
                    fieldId: .patientGender,
                    value: "female",
                    sourceQuote: quote,
                )],
                unmappedFindings: [],
            )
            let result = try DNeuralUltrasoundProposalProcessor.validate(
                generated: generated,
                request: request,
            )
            #expect(
                result.proposals.isEmpty,
            )
            #expect(
                result.rejectedFieldIds == [.patientGender],
            )
        }
        let patient = try proposal(
            field: .patientGender,
            value: "female",
            quote: "Gender female",
            dictation: "Gender female. Fetal sex is male.",
            locale: "en_US",
        )
        #expect(
            patient.warnings.isEmpty,
        )
    }

    @Test(
        "A complaint that omits a following negative sentence needs review",
    )
    func incompleteComplaint() throws {
        let text = "Pain over the right elbow after lifting. No pain at rest. Ultrasound shows no joint effusion."
        let partial = try proposal(
            field: .patientComplaints,
            value: "Pain over the right elbow after lifting.",
            quote: "Pain over the right elbow after lifting.",
            dictation: text,
            locale: "en_US",
        )
        let complete = try proposal(
            field: .patientComplaints,
            value: "Pain over the right elbow after lifting. No pain at rest.",
            quote: "Pain over the right elbow after lifting. No pain at rest.",
            dictation: text,
            locale: "en_US",
        )
        #expect(
            partial.warnings.contains(
                .ambiguousDictation,
            ),
        )
        #expect(
            complete.warnings.isEmpty,
        )
    }

    @Test(
        "A description that mixes a complaint with findings needs review",
    )
    func mixedClinicalSections() throws {
        let text = "The patient complains of abdominal pain. No nausea. Ultrasound shows no free fluid."
        let result = try proposal(
            field: .examinationDescription,
            value: text,
            quote: text,
            locale: "en_US",
        )
        #expect(
            result.warnings.contains(
                .ambiguousDictation,
            ),
        )
    }

    @Test(
        "No complaints alone cannot populate an ultrasound description",
    )
    func noComplaintsIsNotFinding() throws {
        for (code, text) in [("en_US", "No complaints."), ("ru_RU", "Жалоб нет.")] {
            let request = DNeuralUltrasoundDictationParseRequest(
                text: text,
                examinationTypeId: "abdominalCavity",
                examinationTypeTitle: "Unit-test examination",
                locale: Locale(
                    identifier: code,
                ),
                allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
                localization: VoiceLocalizationTestSupport.dictation(
                    locale: Locale(
                        identifier: code,
                    ),
                ),
            )
            let generated = DNeuralUltrasoundProposalGenerationResponse(
                proposals: [DNeuralUltrasoundProposalGenerationItem(
                    fieldId: .examinationDescription,
                    value: text,
                    sourceQuote: text,
                )],
                unmappedFindings: [],
            )
            let result = try DNeuralUltrasoundProposalProcessor.validate(
                generated: generated,
                request: request,
            )
            #expect(
                result.proposals.isEmpty,
            )
            #expect(
                result.rejectedFieldIds == [.examinationDescription],
            )
        }
    }

    @Test(
        "Height and weight in one quote are checked against their own units",
    )
    func separateMeasurementEvidence() throws {
        let quote = "Weight 71.6 kg and height 174 cm."
        let weight = try proposal(
            field: .patientWeightKG,
            value: "71.6",
            quote: quote,
            locale: "en_US",
        )
        let height = try proposal(
            field: .patientHeightCM,
            value: "174",
            quote: quote,
            locale: "en_US",
        )
        let wrongUnit = try validatorWarnings(
            field: .patientHeightCM,
            value: "174",
            quote: "Height 174 mm. Kidney length 174 cm.",
            locale: "en_US",
        )
        #expect(
            weight.warnings.isEmpty,
        )
        #expect(
            height.warnings.isEmpty,
        )
        #expect(
            wrongUnit.contains(
                .unitMismatch,
            ),
        )
    }

    @Test(
        "A correction after a full stop still requires review",
    )
    func followingSentenceCorrection() throws {
        let result = try proposal(
            field: .examinationDescription,
            value: "Right kidney 12 mm",
            quote: "Right kidney 12 mm",
            dictation: "Right kidney 12 mm. No, left kidney 14 mm.",
            locale: "en_US",
        )
        #expect(
            result.warnings.contains(
                .ambiguousDictation,
            ),
        )
    }

    private func proposal(
        field: DNeuralUltrasoundVoiceFieldId,
        value: String,
        quote: String,
        dictation: String? = nil,
        locale: String = "ru_RU",
    ) throws -> DNeuralUltrasoundVoiceFieldProposal {
        let request = DNeuralUltrasoundDictationParseRequest(
            text: dictation ?? quote,
            examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
            examinationTypeTitle: "Unit-test examination",
            locale: Locale(
                identifier: locale,
            ),
            allowedFields: [field],
            localization: VoiceLocalizationTestSupport.dictation(
                locale: Locale(
                    identifier: locale,
                ),
            ),
        )
        let generated = DNeuralUltrasoundProposalGenerationResponse(
            proposals: [DNeuralUltrasoundProposalGenerationItem(
                fieldId: field,
                value: value,
                sourceQuote: quote,
            )],
            unmappedFindings: [],
        )
        return try #require(
            DNeuralUltrasoundProposalProcessor.validate(
                generated: generated,
                request: request,
            ).proposals.first,
        )
    }

    private func validatorWarnings(
        field: DNeuralUltrasoundVoiceFieldId,
        value: String,
        quote: String,
        locale: String = "ru_RU",
    ) throws -> [DNeuralVoiceProposalWarning] {
        let parsed = try DNeuralVoiceFieldValue.parse(
            fieldId: field,
            text: value,
            locale: Locale(
                identifier: locale,
            ),
            localization: VoiceLocalizationTestSupport.dictation(
                locale: Locale(
                    identifier: locale,
                ),
            ),
        )
        let request = DNeuralUltrasoundDictationParseRequest(
            text: quote,
            examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
            examinationTypeTitle: "Unit-test examination",
            locale: Locale(
                identifier: locale,
            ),
            allowedFields: [field],
            localization: VoiceLocalizationTestSupport.dictation(
                locale: Locale(
                    identifier: locale,
                ),
            ),
        )
        return DNeuralUltrasoundDictationProposalValidator.warnings(
            fieldId: field,
            value: parsed,
            sourceQuote: quote,
            request: request,
        )
    }
}

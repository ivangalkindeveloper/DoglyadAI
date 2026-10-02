@testable import DoglyadNeuralModel
import Foundation
import Testing

struct DictationProposalValidatorTests {
    @Test("A changed side is flagged in Russian")
    func changedSide() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Левая почка 12 мм",
            quote: "Правая почка 12 мм"
        ).warnings
        #expect(warnings.contains(.sideMismatch))
    }

    @Test("A lost negation is flagged in English")
    func lostNegation() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Free fluid",
            quote: "No free fluid",
            locale: "en_US"
        ).warnings
        #expect(warnings.contains(.negationMismatch))
    }

    @Test("Changed negation scope with the same word count is still flagged")
    func switchedNegationScope() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Aortic valve without regurgitation. Mitral valve with regurgitation.",
            quote: "Mitral valve without regurgitation. Aortic valve with regurgitation.",
            locale: "en_US"
        ).warnings
        #expect(warnings.contains(.textChanged))
    }

    @Test("A discourse correction marked by punctuation needs review")
    func discourseCorrection() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "No lesions present",
            quote: "No, lesions present",
            locale: "en_US"
        ).warnings
        #expect(warnings.contains(.ambiguousDictation))
    }

    @Test("Changed numbers and units are flagged independently")
    func changedMeasurement() throws {
        let changedNumber = try proposal(
            field: .examinationDescription,
            value: "Right kidney 14 mm",
            quote: "Right kidney 12 mm",
            locale: "en_US"
        )
        let changedUnit = try proposal(
            field: .examinationDescription,
            value: "Right kidney 12 cm",
            quote: "Right kidney 12 mm",
            locale: "en_US"
        )
        #expect(changedNumber.warnings.contains(.numberMismatch))
        #expect(!changedNumber.warnings.contains(.unitMismatch))
        #expect(changedUnit.warnings.contains(.unitMismatch))
    }

    @Test("Swapped number-unit pairs are flagged")
    func swappedUnits() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "12 cm and 5 mm",
            quote: "12 mm and 5 cm",
            locale: "en_US"
        ).warnings
        #expect(warnings.contains(.unitMismatch))
    }

    @Test("A correction outside the exact quote is still flagged")
    func nearbyCorrection() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "15 mm",
            quote: "15 mm",
            dictation: "Right kidney 12, no, 15 mm.",
            locale: "en_US"
        ).warnings
        #expect(warnings.contains(.ambiguousDictation))
    }

    @Test("Spoken-number corrections need review even when copied literally")
    func spokenNumberCorrection() throws {
        let english = try proposal(
            field: .examinationDescription,
            value: "middle cerebral artery: sixty five, no, sixty two centimeters per second",
            quote: "middle cerebral artery: sixty five, no, sixty two centimeters per second",
            locale: "en_US"
        )
        let russian = try proposal(
            field: .examinationDescription,
            value: "общая сонная артерия: восемь, нет, пять миллиметров",
            quote: "общая сонная артерия: восемь, нет, пять миллиметров"
        )
        #expect(english.warnings.contains(.ambiguousDictation))
        #expect(russian.warnings.contains(.ambiguousDictation))
    }

    @Test("A quote omitting the rest of an ultrasound observation needs review")
    func incompleteObservationQuote() throws {
        let partial = try proposal(
            field: .examinationDescription,
            value: "mucosal thickening: three millimeters",
            quote: "On ultrasound, mucosal thickening: three millimeters",
            dictation: "On ultrasound, mucosal thickening: three millimeters. No additional abnormality.",
            locale: "en_US"
        )
        let complete = try proposal(
            field: .examinationDescription,
            value: "mucosal thickening: three millimeters. No additional abnormality.",
            quote: "On ultrasound, mucosal thickening: three millimeters. No additional abnormality.",
            locale: "en_US"
        )
        #expect(partial.warnings.contains(.ambiguousDictation))
        #expect(!complete.warnings.contains(.ambiguousDictation))
    }

    @Test("A complaint quoted as an ultrasound finding needs review")
    func complaintAsObservation() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "отёчность",
            quote: "отёчность",
            dictation: "На УЗИ остаточная моча 24 мл. Сообщает: отёчность, вес 66 кг"
        ).warnings
        #expect(warnings.contains(.ambiguousDictation))
    }

    @Test("A complaint quote containing a measurement requires review")
    func observationAsComplaint() throws {
        let warnings = try proposal(
            field: .patientComplaints,
            value: "swelling ultrasound right ventricle 47 mm",
            quote: "they report swelling ultrasound right ventricle 47 mm",
            locale: "en_US"
        ).warnings
        #expect(warnings.contains(.ambiguousDictation))
    }

    @Test("A correction in the next dictated clause flags the earlier quote")
    func followingCorrection() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Правая почка 12 мм",
            quote: "Правая почка 12 мм",
            dictation: "Правая почка 12 мм; нет, левая почка 14 мм"
        ).warnings
        #expect(warnings.contains(.ambiguousDictation))
    }

    @Test("A following no-complaints field is not treated as a correction")
    func followingNegativeField() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Right kidney 12 mm",
            quote: "Right kidney 12 mm",
            dictation: "Right kidney 12 mm; no complaints",
            locale: "en_US"
        ).warnings
        #expect(warnings.isEmpty)
    }

    @Test("A conflicting side outside the quoted excerpt is flagged")
    func sideConflictInClause() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Правая почка 12 мм",
            quote: "Правая почка 12 мм",
            dictation: "Правая почка 12 мм, не левая"
        ).warnings
        #expect(warnings.contains(.ambiguousDictation))
    }

    @Test("A literal clinical description has no detected conflict")
    func literalDescription() throws {
        let warnings = try proposal(
            field: .examinationDescription,
            value: "Правая почка 12 мм. Конкрементов нет.",
            quote: "Описание: Правая почка 12 мм. Конкрементов нет."
        ).warnings
        #expect(warnings.isEmpty)
    }

    @Test("Meters are converted to centimeters when the quoted unit is explicit")
    func heightConversion() throws {
        let correct = try proposal(
            field: .patientHeightCM,
            value: "174",
            quote: "Рост 1,74 м"
        )
        let wrongUnit = try validatorWarnings(
            field: .patientHeightCM,
            value: "174",
            quote: "Рост 174 мм"
        )
        #expect(correct.warnings.isEmpty)
        #expect(wrongUnit.contains(.unitMismatch))
    }

    @Test("Date, gender and leading-zero identifier require explicit support")
    func structuredValues() throws {
        let incompleteDate = try validatorWarnings(
            field: .patientDateOfBirth, value: "1980-01-01", quote: "Дата рождения 1980 год"
        )
        let inferredGender = try validatorWarnings(field: .patientGender, value: "female", quote: "Пациент Иван")
        let numberRequest = DictationParseRequest(
            text: "Номер исследования 007",
            examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
            locale: Locale(identifier: "ru_RU"),
            allowedFields: [.examinationNumber]
        )
        let changedNumberWarnings = DictationProposalValidator.warnings(
            fieldId: .examinationNumber,
            value: .text("7"),
            sourceQuote: "Номер исследования 007",
            request: numberRequest
        )
        let completeDate = try proposal(field: .patientDateOfBirth, value: "1990-01-02", quote: "Дата рождения 02.01.1990")
        let explicitGender = try proposal(field: .patientGender, value: "female", quote: "Пол женский")
        #expect(incompleteDate.contains(.dateUnverified))
        #expect(inferredGender.contains(.genderUnverified))
        #expect(changedNumberWarnings.contains(.identifierMismatch))
        #expect(completeDate.warnings.isEmpty)
        #expect(explicitGender.warnings.isEmpty)
    }

    @Test("Spoken identifier digits keep leading zeros and require the study cue")
    func spokenIdentifier() throws {
        let english = try validatorWarnings(
            field: .examinationNumber,
            value: "026",
            quote: "This is study zero two six.",
            locale: "en_US"
        )
        let russian = try validatorWarnings(
            field: .examinationNumber,
            value: "091",
            quote: "Это исследование номер ноль девять один."
        )
        let wrong = try validatorWarnings(
            field: .examinationNumber,
            value: "26",
            quote: "This is study zero two six.",
            locale: "en_US"
        )
        #expect(!english.contains(.identifierMismatch))
        #expect(!russian.contains(.identifierMismatch))
        #expect(wrong.contains(.identifierMismatch))
    }

    @Test("Spoken cardinal measurements support their normalized numeric values")
    func spokenMeasurements() throws {
        let height = try validatorWarnings(
            field: .patientHeightCM,
            value: "182",
            quote: "one hundred eighty two centimeters tall",
            locale: "en_US"
        )
        let weight = try validatorWarnings(
            field: .patientWeightKG,
            value: "66",
            quote: "вес шестьдесят шесть килограммов"
        )
        let wrong = try validatorWarnings(
            field: .patientWeightKG,
            value: "60",
            quote: "вес шестьдесят шесть килограммов"
        )
        #expect(!height.contains(.numberMismatch))
        #expect(!weight.contains(.numberMismatch))
        #expect(wrong.contains(.numberMismatch))
    }

    @Test("A spoken month date is verified against the proposed date")
    func spokenMonthDate() throws {
        let matching = try proposal(
            field: .patientDateOfBirth,
            value: "1974-10-23",
            quote: "Date of birth October 23, 1974",
            locale: "en_US"
        )
        let different = try proposal(
            field: .patientDateOfBirth,
            value: "1974-10-24",
            quote: "Date of birth October 23, 1974",
            locale: "en_US"
        )
        #expect(!matching.warnings.contains(.dateUnverified))
        #expect(different.warnings.contains(.dateUnverified))
    }

    @Test("Woman and man explicitly support a gender proposal")
    func spokenGenderNouns() throws {
        let woman = try proposal(field: .patientGender, value: "female", quote: "A woman", locale: "en_US")
        let man = try proposal(field: .patientGender, value: "male", quote: "A man", locale: "en_US")
        #expect(woman.warnings.isEmpty)
        #expect(man.warnings.isEmpty)
    }

    @Test("An unrelated number cannot silently become the examination number")
    func unrelatedNumber() throws {
        let englishQuote = "Insurance number: 007."
        let russianQuote = "Номер полиса: 007."
        let englishRequest = DictationParseRequest(
            text: englishQuote,
            examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
            locale: Locale(identifier: "en_US"),
            allowedFields: [.examinationNumber]
        )
        let russianRequest = DictationParseRequest(
            text: russianQuote,
            examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
            locale: Locale(identifier: "ru_RU"),
            allowedFields: [.examinationNumber]
        )
        let english = DictationProposalValidator.warnings(
            fieldId: .examinationNumber, value: .text("007"), sourceQuote: englishQuote, request: englishRequest
        )
        let russian = DictationProposalValidator.warnings(
            fieldId: .examinationNumber, value: .text("007"), sourceQuote: russianQuote, request: russianRequest
        )
        let examination = try proposal(field: .examinationNumber, value: "007", quote: "Номер исследования: 007.")
        #expect(english.contains(.identifierMismatch))
        #expect(russian.contains(.identifierMismatch))
        #expect(examination.warnings.isEmpty)
    }

    private func proposal(
        field: VoiceFieldId,
        value: String,
        quote: String,
        dictation: String? = nil,
        locale: String = "ru_RU"
    ) throws -> VoiceFieldProposal {
        let request = DictationParseRequest(
            text: dictation ?? quote,
            examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
            locale: Locale(identifier: locale),
            allowedFields: [field]
        )
        let generated = DExaminationProposalGenerationResponse(
            proposals: [DExaminationProposalGenerationItem(fieldId: field, value: value, sourceQuote: quote)],
            unmappedFindings: []
        )
        return try #require(DictationProposal(generated: generated, request: request).proposals.first)
    }

    private func validatorWarnings(
        field: VoiceFieldId, value: String, quote: String, locale: String = "ru_RU"
    ) throws -> [VoiceProposalWarning] {
        let parsed = try VoiceFieldValue.parse(fieldId: field, text: value, locale: Locale(identifier: locale))
        let request = DictationParseRequest(
            text: quote,
            examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
            locale: Locale(identifier: locale),
            allowedFields: [field]
        )
        return DictationProposalValidator.warnings(fieldId: field, value: parsed, sourceQuote: quote, request: request)
    }
}

@testable import DoglyadNeuralModel
import Foundation
import Testing

struct DictationExplicitFactsExtractorTests {
    @Test("An attached unit does not hide an explicitly corrected measurement")
    func attachedCorrectedUnit() {
        let locale = Locale(identifier: "en_US")
        let description = DictationDescriptionNormalizer.normalize(
            "wall thickness, 7, no, 4mm. No additional abnormality.", locale: locale
        )
        #expect(description == "wall thickness: 4 mm. No additional abnormality.")
    }

    @Test("Abbreviated velocity units retain the spoken measurement")
    func abbreviatedVelocityUnit() {
        let locale = Locale(identifier: "en_US")
        let description = DictationDescriptionNormalizer.normalize(
            "middle cerebral artery, 72 cm per second. No additional abnormality.", locale: locale
        )
        #expect(description == "middle cerebral artery: 72 cm/s. No additional abnormality.")
    }

    @Test("Russian abbreviated velocity remains a single measurement")
    func russianAbbreviatedVelocityUnit() {
        let description = DictationDescriptionNormalizer.normalize(
            "средняя мозговая артерия, 75 см в секунду. Дополнительных изменений не выявлено.",
            locale: Locale(identifier: "ru_RU")
        )
        #expect(description == "средняя мозговая артерия: 75 см/с. Дополнительных изменений не выявлено.")
    }

    @Test("An explicitly spoken velocity survives missing or changed punctuation")
    func velocityWithoutComma() {
        let locale = Locale(identifier: "ru_RU")
        for separator in [" – ", " "] {
            let description = DictationDescriptionNormalizer.normalize(
                "средняя мозговая артерия\(separator)65 см в секунду. Дополнительных изменений не выявлено.",
                locale: locale
            )
            #expect(description == "средняя мозговая артерия: 65 см/с. Дополнительных изменений не выявлено.")
        }
    }

    @Test("A decimal measurement is not silently changed into an integer")
    func decimalMeasurementRemainsUnchanged() {
        let description = "wall thickness 1.5 mm."
        #expect(DictationDescriptionNormalizer.normalize(description, locale: Locale(identifier: "en_US")) == description)
    }

    @Test("A punctuated study number retains every dictated digit")
    func punctuatedStudyNumber() {
        for (spoken, expected) in [("0,1,1", "011"), ("0,25", "025")] {
            let request = DictationParseRequest(
                text: "Это исследование номер \(spoken). На УЗИ печень, 140 мм.",
                examinationTypeId: "abdominalCavity", locale: Locale(identifier: "ru_RU"),
                allowedFields: VoiceFieldId.allCases
            )
            #expect(DictationExplicitFactsExtractor.extract(request: request)
                .first { $0.id == .examinationNumber }?.value == .text(expected))
        }
        let measurement = DictationParseRequest(
            text: "Исследование номер 0,25 см.", examinationTypeId: "abdominalCavity",
            locale: Locale(identifier: "ru_RU"), allowedFields: VoiceFieldId.allCases
        )
        #expect(!DictationExplicitFactsExtractor.extract(request: measurement)
            .contains { $0.id == .examinationNumber })
    }

    @Test("Eight spoken birth-date digits can be grouped in two ASR phrases")
    func twoGroupedSpokenBirthDate() {
        let date = DictationSpokenBirthDate.parse(
            "born two zero zero five, zero nine zero seven", locale: Locale(identifier: "en_US")
        )
        #expect(date != nil)
        #expect(DictationSpokenBirthDate.parse(
            "born two zero zero five, one three zero seven", locale: Locale(identifier: "en_US")
        ) == nil)
    }

    @Test("Phonetic spellings of the ultrasound cue still split complaints from findings")
    func compactRussianObservationCue() {
        for cue in ["науззаи", "науззая", "на уззай", "наузза и", "на уззая и"] {
            let request = DictationParseRequest(
                text: "Сообщает, болезненность, \(cue) правый желудочек, 47 мм. "
                    + "Дополнительных изменений не выявлено.",
                examinationTypeId: "echocardiography", locale: Locale(identifier: "ru_RU"),
                allowedFields: VoiceFieldId.allCases
            )
            let fields = DictationExplicitFactsExtractor.extract(request: request)
            #expect(fields.first { $0.id == .patientComplaints }?.value == .text("болезненность"))
            #expect(fields.first { $0.id == .examinationDescription }?.value
                == .text("правый желудочек: 47 мм. Дополнительных изменений не выявлено."))
        }
    }

    @Test("English free dictation keeps each explicit field and the full observation")
    func englishIndependentCueWording() {
        let request = DictationParseRequest(
            text: "File reference 097 is for Olivia Carter, female, born on 1984-03-09. "
                + "Their height is 179 centimeters, with a body weight of 110 kilograms. "
                + "The presenting concern is intermittent pain. "
                + "Sonographic observations: right ventricle: 52 mm. No additional abnormality.",
            examinationTypeId: "echocardiography", locale: Locale(identifier: "en_US"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.count == 8)
        #expect(fields.first { $0.id == .examinationNumber }?.value == .text("097"))
        #expect(fields.first { $0.id == .examinationNumber }?.warnings.isEmpty == true)
        #expect(fields.first { $0.id == .patientName }?.value == .text("Olivia Carter"))
        #expect(fields.first { $0.id == .patientGender }?.value == .gender(.female))
        #expect(fields.first { $0.id == .patientHeightCM }?.value == .number(179))
        #expect(fields.first { $0.id == .patientWeightKG }?.value == .number(110))
        #expect(fields.first { $0.id == .patientComplaints }?.value == .text("intermittent pain"))
        #expect(fields.first { $0.id == .examinationDescription }?.value
            == .text("right ventricle: 52 mm. No additional abnormality."))
        #expect(fields.first { $0.id == .examinationDescription }?.warnings.isEmpty == true)
    }

    @Test("Russian free dictation keeps the observation before later measurements")
    func russianIndependentCueWording() {
        let request = DictationParseRequest(
            text: "По протоколу 062 пациент отмечает отёчность. "
                + "Сонография показала левый желудочек: 37 мм. Дополнительных изменений не выявлено. "
                + "Измеренная масса тела 85 килограммов.",
            examinationTypeId: "echocardiography", locale: Locale(identifier: "ru_RU"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.map(\.id) == [
            .examinationNumber, .patientWeightKG, .patientComplaints, .examinationDescription,
        ])
        #expect(fields.first { $0.id == .examinationNumber }?.value == .text("062"))
        #expect(fields.first { $0.id == .examinationNumber }?.warnings.isEmpty == true)
        #expect(fields.first { $0.id == .patientWeightKG }?.value == .number(85))
        #expect(fields.first { $0.id == .patientComplaints }?.value == .text("отёчность"))
        #expect(fields.first { $0.id == .examinationDescription }?.value
            == .text("левый желудочек: 37 мм. Дополнительных изменений не выявлено."))
        #expect(fields.first { $0.id == .examinationDescription }?.warnings.isEmpty == true)
    }

    @Test("An observation followed by a study number has a complete source quote")
    func observationBeforeStudyNumber() {
        let request = DictationParseRequest(
            text: "On imaging, left kidney: 35 mm. No additional abnormality. "
                + "This was filed as study 062.",
            examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
            locale: Locale(identifier: "en_US"), allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.first { $0.id == .examinationNumber }?.warnings.isEmpty == true)
        #expect(fields.first { $0.id == .examinationDescription }?.warnings.isEmpty == true)
        #expect(fields.first { $0.id == .examinationDescription }?.value
            == .text("left kidney: 35 mm. No additional abnormality."))
    }

    @Test("English observation boundary excludes the next sentence marker from complaints")
    func englishSonographicBoundary() {
        let request = DictationParseRequest(
            text: "The reported problem is intermittent pain. The sonographic examination showed "
                + "common carotid artery: 9 mm. No additional abnormality.",
            examinationTypeId: "brachiocephalicVessels", locale: Locale(identifier: "en_US"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.first { $0.id == .patientComplaints }?.value == .text("intermittent pain"))
        #expect(fields.first { $0.id == .examinationDescription }?.value
            == .text("common carotid artery: 9 mm. No additional abnormality."))
    }

    @Test("A later negative sentence cannot disappear from a model finding without warning")
    func englishSonogramQuoteMustBeComplete() {
        let text = "On the sonogram I see liver: 143 mm. No additional abnormality. "
            + "This belongs to protocol 014."
        let request = DictationParseRequest(
            text: text, examinationTypeId: "abdominalCavity", locale: Locale(identifier: "en_US"),
            allowedFields: VoiceFieldId.allCases
        )
        let warnings = DictationProposalValidator.warnings(
            fieldId: .examinationDescription, value: .text("Liver: 143 mm."),
            sourceQuote: "On the sonogram I see liver: 143 mm.", request: request
        )
        #expect(warnings.contains(.ambiguousDictation))
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.first { $0.id == .examinationDescription }?.value
            == .text("liver: 143 mm. No additional abnormality."))
    }

    @Test("Russian complaint and subsequent record number have separate boundaries")
    func russianComplaintAndRecordBoundary() {
        let text = "Сообщает о болезненность. На эхограмме видно левый желудочек: 44 мм. "
            + "Дополнительных изменений не выявлено. Это протокол 026."
        let request = DictationParseRequest(
            text: text, examinationTypeId: "echocardiography", locale: Locale(identifier: "ru_RU"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.first { $0.id == .patientComplaints }?.value == .text("болезненность"))
        #expect(fields.first { $0.id == .examinationDescription }?.value
            == .text("левый желудочек: 44 мм. Дополнительных изменений не выявлено."))
        #expect(fields.first { $0.id == .examinationDescription }?.warnings.isEmpty == true)
    }

    @Test("A scan measurement without a number label is not a study identifier")
    func scanMeasurementIsNotIdentifier() {
        let request = DictationParseRequest(
            text: "The scan 52 mm shows a right ventricle. No additional abnormality.",
            examinationTypeId: "echocardiography", locale: Locale(identifier: "en_US"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(!fields.contains { $0.id == .examinationNumber })

        let russian = DictationParseRequest(
            text: "Исследование 52 мм, дополнительных изменений не выявлено.",
            examinationTypeId: "echocardiography", locale: Locale(identifier: "ru_RU"),
            allowedFields: VoiceFieldId.allCases
        )
        #expect(!DictationExplicitFactsExtractor.extract(request: russian)
            .contains { $0.id == .examinationNumber })
    }

    @Test("A bare number is an examination number only at the start of dictation")
    func initialBareNumber() {
        let english = DictationParseRequest(
            text: "Number 007. On ultrasound, left kidney: 35 mm.",
            examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
            locale: Locale(identifier: "en_US"), allowedFields: VoiceFieldId.allCases
        )
        #expect(DictationExplicitFactsExtractor.extract(request: english)
            .first { $0.id == .examinationNumber }?.value == .text("007"))

        let insurance = DictationParseRequest(
            text: "Insurance number 007. On ultrasound, left kidney: 35 mm.",
            examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
            locale: Locale(identifier: "en_US"), allowedFields: VoiceFieldId.allCases
        )
        #expect(!DictationExplicitFactsExtractor.extract(request: insurance)
            .contains { $0.id == .examinationNumber })
    }

    @Test("A different English clinical narration retains the following field boundary")
    func englishProtocolNarration() {
        let request = DictationParseRequest(
            text: "Patient details: Olivia Carter, female, date of birth 1984-03-09. "
                + "Stature 179 centimeters; body mass 110 kilograms. The patient complains of intermittent pain. "
                + "Ultrasound demonstrates right ventricle: 52 mm. No additional abnormality. Reference number 097.",
            examinationTypeId: "echocardiography", locale: Locale(identifier: "en_US"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.first { $0.id == .examinationNumber }?.value == .text("097"))
        #expect(fields.first { $0.id == .patientName }?.value == .text("Olivia Carter"))
        #expect(fields.first { $0.id == .patientGender }?.value == .gender(.female))
        #expect(fields.first { $0.id == .patientHeightCM }?.value == .number(179))
        #expect(fields.first { $0.id == .patientWeightKG }?.value == .number(110))
        #expect(fields.first { $0.id == .patientComplaints }?.value == .text("intermittent pain"))
        #expect(fields.first { $0.id == .examinationDescription }?.value
            == .text("right ventricle: 52 mm. No additional abnormality."))
    }

    @Test("A Russian observation cue includes the negative sentence")
    func russianObservationWithNegation() {
        let request = DictationParseRequest(
            text: "Пациент Ирина Белова, пол женщина. Номер исследования 097. "
                + "Повод обследования: периодическая боль. "
                + "Ультразвуковая картина следующая: левый желудочек: 40 мм. "
                + "Дополнительных изменений не выявлено.",
            examinationTypeId: "echocardiography", locale: Locale(identifier: "ru_RU"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.first { $0.id == .patientComplaints }?.value == .text("периодическая боль"))
        #expect(fields.first { $0.id == .examinationDescription }?.value
            == .text("левый желудочек: 40 мм. Дополнительных изменений не выявлено."))
    }

    @Test("Explicit English facts retain a quoted value and leading zeros")
    func englishFacts() {
        let request = DictationParseRequest(
            text: "For Anna Morgan, born one nine seven two, zero eight, zero two, the recorded sex is female. "
                + "They are one hundred eighty two centimeters tall and weigh eighty kilograms. "
                + "This is study zero two six. They report swelling. On ultrasound, right ventricle: forty seven millimeters.",
            examinationTypeId: "echocardiography",
            locale: Locale(identifier: "en_US"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.count == 8)
        #expect(fields.first(where: { $0.id == .examinationNumber })?.value == .text("026"))
        #expect(fields.first(where: { $0.id == .patientName })?.value == .text("Anna Morgan"))
        #expect(fields.first(where: { $0.id == .patientGender })?.value == .gender(.female))
        #expect(fields.first(where: { $0.id == .patientHeightCM })?.value == .number(182))
        #expect(fields.first(where: { $0.id == .patientWeightKG })?.value == .number(80))
        #expect(fields.first(where: { $0.id == .patientDateOfBirth })?.value != nil)
        let complaint = fields.first(where: { $0.id == .patientComplaints })
        #expect(complaint?.value == .text("swelling"))
        #expect(complaint?.sourceQuote == "They report swelling.")
        #expect(fields.first(where: { $0.id == .examinationDescription })?.value == .text("right ventricle: 47 mm."))
        #expect(fields.allSatisfy { request.text.contains($0.sourceQuote) })
    }

    @Test("Explicit Russian facts parse independent birth-date groups")
    func russianFacts() {
        let request = DictationParseRequest(
            text: "На приёме Дмитрий Орлов, один девять девять семь, ноль один, два ноль года рождения, мужчина. "
                + "Рост сто семьдесят семь сантиметров, вес девяносто пять килограммов. "
                + "Это исследование номер ноль девять пять. Сообщает: периодическая боль. "
                + "На УЗИ правый желудочек: сорок семь миллиметров.",
            examinationTypeId: "echocardiography",
            locale: Locale(identifier: "ru_RU"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.count == 8)
        #expect(fields.first(where: { $0.id == .examinationNumber })?.value == .text("095"))
        #expect(fields.first(where: { $0.id == .patientName })?.value == .text("Дмитрий Орлов"))
        #expect(fields.first(where: { $0.id == .patientGender })?.value == .gender(.male))
        #expect(fields.first(where: { $0.id == .patientHeightCM })?.value == .number(177))
        #expect(fields.first(where: { $0.id == .patientWeightKG })?.value == .number(95))
        #expect(fields.first(where: { $0.id == .patientDateOfBirth })?.value != nil)
        #expect(fields.first(where: { $0.id == .patientComplaints })?.value == .text("периодическая боль"))
        #expect(fields.first(where: { $0.id == .examinationDescription })?.value == .text("правый желудочек: 47 мм."))
        #expect(fields.allSatisfy { request.text.contains($0.sourceQuote) })
    }

    @Test("Absent fields stay absent in a partial dictation")
    func partialFacts() {
        let request = DictationParseRequest(
            text: "On ultrasound, left ventricle: forty one, no, thirty eight millimeters. "
                + "This is study zero five four; they report swelling and weigh seventy five kilograms.",
            examinationTypeId: "echocardiography",
            locale: Locale(identifier: "en_US"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.map(\.id) == [.examinationNumber, .patientWeightKG, .patientComplaints, .examinationDescription])
        #expect(fields[0].value == .text("054"))
        #expect(fields[1].value == .number(75))
        #expect(fields[2].value == .text("swelling"))
        #expect(fields[3].value == .text("left ventricle: 38 mm."))
    }

    @Test("A bare ultrasound cue separates complaints from findings")
    func missingBoundary() {
        let request = DictationParseRequest(
            text: "This is study 026 they report swelling ultrasound right ventricle 47 mm no additional abnormality",
            examinationTypeId: "echocardiography",
            locale: Locale(identifier: "en_US"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.first(where: { $0.id == .patientComplaints })?.value == .text("swelling"))
        #expect(!fields.contains(where: { $0.id == .examinationDescription }))
    }

    @Test("Russian ASR abbreviations and a year-first compact date retain explicit facts")
    func russianASRAbbreviations() {
        let request = DictationParseRequest(
            text: "На приеме Дмитрий Орлов 19970120 года рождения мужчина рост 177 см вес 95 кг "
                + "это исследование номер 095 сообщает периодическая боль на правый желудочек 47 мм",
            examinationTypeId: "echocardiography",
            locale: Locale(identifier: "ru_RU"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.first(where: { $0.id == .patientName })?.value == .text("Дмитрий Орлов"))
        #expect(fields.first(where: { $0.id == .patientDateOfBirth })?.value != nil)
        #expect(fields.first(where: { $0.id == .patientHeightCM })?.value == .number(177))
        #expect(fields.first(where: { $0.id == .patientWeightKG })?.value == .number(95))
        #expect(!fields.contains(where: { $0.id == .patientComplaints }))
    }

    @Test("Russian patient name survives separated numeric birth dates")
    func russianNameWithNoisyDate() {
        for date in ["199701, 00", "1,977, 04, 1,7", "1995-03-08", "1-9-8-4, 1-1, 1-8"] {
            let request = DictationParseRequest(
                text: "На приеме Дмитрий Орлов, \(date) года рождения, мужчина. Рост 177 см.",
                examinationTypeId: "echocardiography", locale: Locale(identifier: "ru_RU"),
                allowedFields: VoiceFieldId.allCases
            )
            let fields = DictationExplicitFactsExtractor.extract(request: request)
            #expect(fields.first(where: { $0.id == .patientName })?.value == .text("Дмитрий Орлов"))
        }

        let unrelated = DictationParseRequest(
            text: "На приеме признаки воспаления почки, размер 12 мм.",
            examinationTypeId: "echocardiography", locale: Locale(identifier: "ru_RU"),
            allowedFields: VoiceFieldId.allCases
        )
        #expect(!DictationExplicitFactsExtractor.extract(request: unrelated).contains { $0.id == .patientName })
    }

    @Test("A complete eight-digit year-first birth date survives separators inside its groups")
    func russianBirthDateWithInternalSeparators() {
        let examples = [
            ("1,977, 04, 1,7", "1977-04-17"),
            ("1-979-07-28", "1979-07-28"),
            ("1-9-8-9-0-4-0-7", "1989-04-07"),
        ]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        for (spoken, expected) in examples {
            let request = DictationParseRequest(
                text: "На приеме Дмитрий Орлов, \(spoken) года рождения, мужчина.",
                examinationTypeId: "echocardiography", locale: Locale(identifier: "ru_RU"),
                allowedFields: VoiceFieldId.allCases
            )
            let fields = DictationExplicitFactsExtractor.extract(request: request)
            guard case let .date(date) = fields.first(where: { $0.id == .patientDateOfBirth })?.value else {
                Issue.record("Expected birth date from \(spoken)")
                continue
            }
            #expect(formatter.string(from: date) == expected)
        }

        let incomplete = DictationParseRequest(
            text: "На приеме Дмитрий Орлов, 199701, 00 года рождения, мужчина.",
            examinationTypeId: "echocardiography", locale: Locale(identifier: "ru_RU"),
            allowedFields: VoiceFieldId.allCases
        )
        #expect(!DictationExplicitFactsExtractor.extract(request: incomplete)
            .contains { $0.id == .patientDateOfBirth })
    }

    @Test("A recognizer's split Russian ultrasound cue still separates complaints and findings")
    func russianUltrasoundCueVariants() {
        for cue in ["На УЗИ", "На УЗАИ", "На УЗЭ и", "На УЗ и"] {
            let request = DictationParseRequest(
                text: "Это исследование номер 095. Сообщает, боль справа. \(cue) правая почка 47 мм. Дополнительных изменений не выявлено.",
                examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
                locale: Locale(identifier: "ru_RU"), allowedFields: VoiceFieldId.allCases
            )
            let fields = DictationExplicitFactsExtractor.extract(request: request)
            #expect(fields.first(where: { $0.id == .patientComplaints })?.value == .text("боль справа"))
            let description = fields.first(where: { $0.id == .examinationDescription })
            guard case let .text(value) = description?.value else {
                Issue.record("Expected an examination description after \(cue)")
                continue
            }
            #expect(value.contains("правая почка"))
            #expect(request.text.contains(description?.sourceQuote ?? ""))
        }
    }

    @Test("English ASR sentence break preserves an explicit birth date")
    func englishASRSentenceBreakBeforeGender() {
        for text in [
            "For Anna Morgan born 19720802. The recorded sex female. They are 182 cm tall.",
            "For Anna Morgan born 19720802. The recorded six female. They are 182 cm tall.",
        ] {
            let request = DictationParseRequest(
                text: text,
                examinationTypeId: "echocardiography",
                locale: Locale(identifier: "en_US"),
                allowedFields: VoiceFieldId.allCases
            )
            let fields = DictationExplicitFactsExtractor.extract(request: request)
            let date = fields.first(where: { $0.id == .patientDateOfBirth })?.value
            guard case let .date(value) = date else {
                Issue.record("Expected a birth date proposal")
                continue
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            #expect(formatter.string(from: value) == "1972-08-02")
        }
    }

    @Test("An ASR sentence break before an explicit measurement preserves the finding")
    func measurementSentenceBreak() {
        let request = DictationParseRequest(
            text: "On ultrasound, right ventricle. 47 millimeters. No additional abnormality.",
            examinationTypeId: "echocardiography",
            locale: Locale(identifier: "en_US"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.first(where: { $0.id == .examinationDescription })?.value
            == .text("right ventricle: 47 mm. No additional abnormality."))
    }

    @Test("Year-first birth dates survive ASR joining the month and day")
    func joinedBirthDate() {
        let request = DictationParseRequest(
            text: "For Anna Morgan, born 1972-0802, the recorded sex is female.",
            examinationTypeId: "echocardiography",
            locale: Locale(identifier: "en_US"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.first(where: { $0.id == .patientDateOfBirth })?.value != nil)
        #expect(fields.first(where: { $0.id == .patientDateOfBirth })?.warnings.contains(.dateUnverified) == false)
    }

    @Test("A new English full-form wording exposes all eight explicitly spoken facts")
    func englishHoldoutWording() {
        let request = DictationParseRequest(
            text: "For study 099 I examined Henry Wilson. Date of birth 1998-02-25; male. "
                + "The patient is 160 centimeters tall and weighs 53 kilograms. "
                + "They complain of tenderness. The scan shows abdominal aorta: 24 mm. No additional abnormality.",
            examinationTypeId: "abdominalVessels", locale: Locale(identifier: "en_US"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.count == 8)
        #expect(fields.first(where: { $0.id == .patientName })?.value == .text("Henry Wilson"))
        #expect(fields.first(where: { $0.id == .patientGender })?.value == .gender(.male))
        #expect(fields.first(where: { $0.id == .patientWeightKG })?.value == .number(53))
        #expect(fields.first(where: { $0.id == .patientComplaints })?.value == .text("tenderness"))
        #expect(fields.first(where: { $0.id == .examinationDescription })?.value
            == .text("abdominal aorta: 24 mm. No additional abnormality."))
        #expect(fields.allSatisfy { request.text.contains($0.sourceQuote) })
    }

    @Test("A new Russian full-form wording exposes all eight explicitly spoken facts")
    func russianHoldoutWording() {
        let request = DictationParseRequest(
            text: "Пациент Наталья Кузнецова, дата рождения 1996-12-08, пол женщина. "
                + "Исследование 064. Рост 189 сантиметров, масса тела 57 килограммов. "
                + "Жалобы: болезненность. Эхографически: левый желудочек: 54 мм. Дополнительных изменений не выявлено.",
            examinationTypeId: "echocardiography", locale: Locale(identifier: "ru_RU"),
            allowedFields: VoiceFieldId.allCases
        )
        let fields = DictationExplicitFactsExtractor.extract(request: request)
        #expect(fields.count == 8)
        #expect(fields.first(where: { $0.id == .examinationNumber })?.value == .text("064"))
        #expect(fields.first(where: { $0.id == .patientName })?.value == .text("Наталья Кузнецова"))
        #expect(fields.first(where: { $0.id == .patientGender })?.value == .gender(.female))
        #expect(fields.first(where: { $0.id == .patientComplaints })?.value == .text("болезненность"))
        #expect(fields.first(where: { $0.id == .examinationDescription })?.value
            == .text("левый желудочек: 54 мм. Дополнительных изменений не выявлено."))
        #expect(fields.allSatisfy { request.text.contains($0.sourceQuote) })
    }

    @Test("A description before complaints does not swallow absent patient fields")
    func reorderedPartialHoldoutWording() {
        let examples = [
            ("en_US", "Study 097: sonography shows right ventricle: 46 mm. No additional abnormality. "
                + "The complaint is intermittent pain; body weight 56 kilograms."),
            ("ru_RU", "Исследование 012: эхографически правый желудочек: 45 мм. "
                + "Дополнительных изменений не выявлено. Из жалоб отёчность; масса тела 52 килограмма."),
        ]
        for (code, text) in examples {
            let request = DictationParseRequest(
                text: text, examinationTypeId: "echocardiography", locale: Locale(identifier: code),
                allowedFields: VoiceFieldId.allCases
            )
            let fields = DictationExplicitFactsExtractor.extract(request: request)
            #expect(Set(fields.map(\.id)) == Set([
                .examinationNumber, .patientWeightKG, .patientComplaints, .examinationDescription,
            ]))
            #expect(fields.first(where: { $0.id == .patientWeightKG })?.value == .number(code == "en_US" ? 56 : 52))
            #expect(fields.allSatisfy { request.text.contains($0.sourceQuote) })
        }
    }

    @MainActor
    @Test("A false complaint label cannot stop complete explicit fact reconciliation")
    func falseComplaintLabelDoesNotStopReconciliation() throws {
        let request = DictationParseRequest(
            text: "Patient Olivia Carter, born 1994-10-03, is female. Study 079. "
                + "Height 162 centimeters; weight 53 kilograms. The concern is no complaints. "
                + "Sonographic findings: common femoral artery: 12 mm. No additional abnormality.",
            examinationTypeId: "arteriesOfTheLowerExtremities", locale: Locale(identifier: "en_US"),
            allowedFields: VoiceFieldId.allCases
        )
        let proposal = DictationProposalReconciler.reconcile(
            request: request,
            labeled: DictationLabeledFormParser.parse(request: request),
            explicit: DictationExplicitFactsExtractor.extract(request: request),
            generated: nil
        )
        #expect(proposal.fieldSources[.patientComplaints] == .explicitFacts)
        #expect(proposal.proposals.count == 8)
        #expect(proposal.proposals.first(where: { $0.id == .patientComplaints })?.value == .text("no complaints"))
    }
}

@testable import DoglyadNeuralModel
import Foundation
import Testing

struct DictationLabeledFormParserTests {
    @Test("Natural prose without leading field labels stays on the model path")
    func leavesFreeformSpeechToModel() {
        let english = "For Anna Morgan, born 1972-08-02, the recorded sex is female. They are 182 centimeters tall and weigh 80 kilograms. This is study 026. They report swelling. On ultrasound, right ventricle: 47 mm. No additional abnormality."
        let russian = "На приёме Дмитрий Орлов, 1997-01-20 года рождения, мужчина. Рост 177 сантиметров, вес 95 килограммов. Это исследование номер 095. Сообщает: периодическая боль. На УЗИ правый желудочек: 47 мм. Дополнительных изменений не выявлено."

        #expect(DictationLabeledFormParser.parse(request: request(english, locale: "en_US")) == nil)
        #expect(DictationLabeledFormParser.parse(request: request(russian, locale: "ru_RU")) == nil)
    }

    @Test("A fully labeled Russian dictation is parsed without the model")
    func parsesRussianFields() throws {
        let text = "Номер исследования: 007; Пациент: Анна Петрова; Пол: женщина; Дата рождения: 1981-04-26; Рост: 174 см; Вес: 64 кг; Жалобы: боль справа; Описание исследования: Правая почка 12 мм. Конкрементов нет."
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "ru_RU")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })

        #expect(proposal.proposals.count == 8)
        #expect(values[.examinationNumber] == .text("007"))
        #expect(values[.patientName] == .text("Анна Петрова"))
        #expect(values[.patientGender] == .gender(.female))
        #expect(values[.patientHeightCM] == .number(174))
        #expect(values[.patientWeightKG] == .number(64))
        #expect(values[.patientComplaints] == .text("боль справа"))
        #expect(values[.examinationDescription] == .text("Правая почка 12 мм. Конкрементов нет."))
        #expect(proposal.rejectedFieldIds.isEmpty)
        #expect(proposal.proposals.allSatisfy { text.contains($0.sourceQuote) })
    }

    @Test("Missing examination number leaves it untouched while other labeled fields are parsed")
    func parsesLabeledFieldsWithoutNumber() throws {
        let text = "Пациент Иванов Иван Иванович дата рождения 28.03.1994 жалобы на боль в печени описание исследования правая доля печени 12 мм"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "ru_RU")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })

        #expect(values[.examinationNumber] == nil)
        #expect(values[.patientName] == .text("Иванов Иван Иванович"))
        let birthDate = try #require(values[.patientDateOfBirth])
        guard case let .date(date) = birthDate else {
            Issue.record("Expected a date proposal")
            return
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        #expect(formatter.string(from: date) == "1994-03-28")
        #expect(values[.patientComplaints] == .text("на боль в печени"))
        #expect(values[.examinationDescription] == .text("правая доля печени 12 мм"))
        #expect(proposal.proposals.count == 4)
        #expect(proposal.proposals.allSatisfy { text.contains($0.sourceQuote) })
    }

    @Test("A single explicitly labeled field is a valid partial dictation")
    func parsesOneExplicitField() throws {
        let text = "Жалобы: боль справа"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "ru_RU")))
        #expect(proposal.proposals.count == 1)
        #expect(proposal.proposals[0].id == .patientComplaints)
        #expect(proposal.proposals[0].value == .text("боль справа"))

        let withUnknown = "Жалобы: боль справа; Номер полиса: 12345"
        let partial = try #require(DictationLabeledFormParser.parse(request: request(withUnknown, locale: "ru_RU")))
        #expect(partial.proposals.count == 1)
        #expect(partial.proposals[0].value == .text("боль справа"))
        #expect(partial.unmappedFindings == ["Номер полиса: 12345"])
    }

    @Test("Labeled English speech needs no punctuation and converts explicit units")
    func parsesEnglishSpeech() throws {
        let text = "Examination number 048 patient Michael Taylor, gender male date of birth October 23, 1974, height 1.88 m weight 71000 g complaints discomfort on the right examination description right ventricle 49 mm no additional abnormality"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })

        #expect(proposal.proposals.count == 8)
        #expect(values[.patientName] == .text("Michael Taylor"))
        #expect(values[.patientGender] == .gender(.male))
        #expect(values[.patientHeightCM] == .number(188))
        #expect(values[.patientWeightKG] == .number(71))
        #expect(values[.patientComplaints] == .text("discomfort on the right"))
        #expect(proposal.rejectedFieldIds.isEmpty)
    }

    @Test("A dropped name cannot populate the patient field with a gender word")
    func rejectsGenderWordAsPatientName() throws {
        let text = "Examination number 030 Patient Male Date of birth 1995-05-11"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        #expect(!proposal.proposals.contains { $0.id == .patientName })
        #expect(proposal.rejectedFieldIds.contains(.patientName))
        #expect(proposal.proposals.contains { $0.id == .examinationNumber })
    }

    @Test("Punctuation separated from a unit does not discard a measurement")
    func parsesMeasurementBeforeSpacedPeriod() throws {
        let text = "Height 185 cm . Weight 70 kg ."
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })
        #expect(values[.patientHeightCM] == .number(185))
        #expect(values[.patientWeightKG] == .number(70))
        #expect(proposal.rejectedFieldIds.isEmpty)
    }

    @Test("ASR commas after labels do not hide typed fields")
    func parsesLabelCommas() throws {
        let text = "Examination number 048, Patient Michael Taylor, Gender, Male, Date of Birth, October 23, 1974, Height, 188 cm, Weight, 71 kg, Complaints, Discomfort on the Right, Examination Description, Right Ventricle, 49 mm, No Additional Abnormality"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })
        #expect(values.count == 8)
        #expect(values[.patientGender] == .gender(.male))
        #expect(values[.patientHeightCM] == .number(188))
        #expect(values[.patientWeightKG] == .number(71))
        #expect(values[.examinationDescription] == .text("Right Ventricle, 49 mm, No Additional Abnormality"))
        #expect(proposal.proposals.allSatisfy { text.contains($0.sourceQuote) })
    }

    @Test("ASR full stops after labels do not hide typed fields")
    func parsesLabelFullStops() throws {
        let text = "Examination number. 048. Patient. Michael Taylor. Gender. Male. Date of birth. October 23, 1974. Height. 188 centimeters. Weight. 71 kilograms. Complaints. Discomfort on the right. Examination description. Right ventricle. 49 millimeters. No additional abnormality."
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })
        #expect(values.count == 8)
        #expect(values[.examinationNumber] == .text("048"))
        #expect(values[.patientName] == .text("Michael Taylor"))
        #expect(values[.patientGender] == .gender(.male))
        #expect(values[.patientHeightCM] == .number(188))
        #expect(values[.patientWeightKG] == .number(71))
        #expect(values[.examinationDescription] == .text("Right ventricle: 49 mm. No additional abnormality."))
    }

    @Test("ASR dashes after Russian labels do not hide typed fields")
    func parsesLabelDashes() throws {
        let text = "Номер исследования – 043. Пациент – Дмитрий Орлов. Пол – мужчина. Дата рождения – 1-9-8-1-0-4-2-6. Рост – 184 см. Вес – 64 кг. Жалобы – дискомфорт справа. Описание исследования – правый желудочек – 37 мм. Дополнительных изменений не выявлено."
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "ru_RU")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })

        #expect(values.count == 8)
        #expect(values[.examinationNumber] == .text("043"))
        #expect(values[.patientName] == .text("Дмитрий Орлов"))
        #expect(values[.patientGender] == .gender(.male))
        #expect(values[.patientHeightCM] == .number(184))
        #expect(values[.patientWeightKG] == .number(64))
        #expect(values[.patientComplaints] == .text("дискомфорт справа."))
        #expect(values[.examinationDescription] == .text("правый желудочек – 37 мм. Дополнительных изменений не выявлено."))
        #expect(proposal.proposals.allSatisfy { text.contains($0.sourceQuote) })
    }

    @Test("ASR punctuation inside an examination identifier requires review")
    func reviewsPunctuatedExaminationNumber() throws {
        for (spoken, expected) in [("0,59", "059"), ("02-7", "027")] {
            let text = "Номер исследования – \(spoken). Пациент – Анна Петрова."
            let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "ru_RU")))
            let number = try #require(proposal.proposals.first { $0.id == .examinationNumber })
            #expect(number.value == .text(expected))
            #expect(number.warnings.contains(.ambiguousDictation))
            #expect(text.contains(number.sourceQuote))
        }
    }

    @Test("Only an unambiguous segmented birth date is restored")
    func checksSegmentedDate() throws {
        let valid = "Номер исследования 043; пациент Дмитрий Орлов пол мужчина дата рождения 19 81 04 26 рост 184 см вес 64 кг жалобы дискомфорт справа описанию исследования правый желудочек 37 мм"
        let validProposal = try #require(DictationLabeledFormParser.parse(request: request(valid, locale: "ru_RU")))
        let date = try #require(validProposal.proposals.first { $0.id == .patientDateOfBirth })
        guard case let .date(parsedDate) = date.value else {
            Issue.record("Expected a date proposal")
            return
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        #expect(formatter.string(from: parsedDate) == "1981-04-26")
        #expect(!date.warnings.contains(.dateUnverified))

        let ambiguous = valid.replacingOccurrences(of: "19 81 04 26", with: "19 80 0 07 27")
        let ambiguousProposal = try #require(DictationLabeledFormParser.parse(request: request(ambiguous, locale: "ru_RU")))
        #expect(!ambiguousProposal.proposals.contains { $0.id == .patientDateOfBirth })
        #expect(ambiguousProposal.rejectedFieldIds.contains(.patientDateOfBirth))
        #expect(ambiguousProposal.proposals.contains { $0.id == .patientHeightCM })
    }

    @Test("A repeated field name inside its value does not force model generation")
    func parsesRepeatedValueWord() throws {
        let text = "Examination number 048 patient Michael Taylor gender male date of birth October 23, 1974 height 188 cm weight 71 kg complaints no complaints examination description right ventricle 49 mm"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })
        #expect(values[.patientComplaints] == .text("no complaints"))
        #expect(values[.examinationDescription] == .text("right ventricle 49 mm"))
    }

    @Test("Missing labels leave affected values empty and preserve the other fields")
    func parsesPartialLabeledSpeech() throws {
        let text = "Examination number 020 patient Anna Morgan gender female date of birth April 18, 1993 height 172 cm 80 kg complaint swelling examination, description right lobe 46 mm"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })
        #expect(values[.patientName] == .text("Anna Morgan"))
        #expect(values[.patientHeightCM] == nil)
        #expect(values[.patientWeightKG] == nil)
        #expect(values[.patientComplaints] == .text("swelling"))
        #expect(values[.examinationDescription] == .text("right lobe 46 mm"))
        #expect(proposal.rejectedFieldIds.contains(.patientHeightCM))
    }

    @Test("Measurement units recover plausible ASR label homophones with a warning")
    func parsesNoisyMeasurementLabels() throws {
        let text = "Examination number 048 patient Michael Taylor gender male date of birth October 23, 1974 high 188 cm weigh 71 kg complaints discomfort on the right examination description right ventricle 49 mm"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })
        #expect(values[.examinationNumber] == .text("048"))
        #expect(values[.patientName] == .text("Michael Taylor"))
        #expect(values[.patientGender] == .gender(.male))
        #expect(values[.patientDateOfBirth] != nil)
        #expect(values[.patientHeightCM] == .number(188))
        #expect(values[.patientWeightKG] == .number(71))
        #expect(values[.patientComplaints] == .text("discomfort on the right"))
        #expect(values[.examinationDescription] == .text("right ventricle 49 mm"))
        #expect(proposal.proposals.first { $0.id == .patientHeightCM }?.warnings.contains(.ambiguousDictation) == true)
        #expect(proposal.proposals.first { $0.id == .patientWeightKG }?.warnings.contains(.ambiguousDictation) == true)
    }

    @Test("Punctuation after a misheard measurement label keeps its warning")
    func warnsOnPunctuatedMeasurementAliases() throws {
        let text = "Examination number 048 patient Michael Taylor gender male date of birth October 23, 1974 high, 188 cm way. 71 kg complaints discomfort examination description right ventricle 49 mm"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        let height = try #require(proposal.proposals.first { $0.id == .patientHeightCM })
        let weight = try #require(proposal.proposals.first { $0.id == .patientWeightKG })
        #expect(height.value == .number(188))
        #expect(weight.value == .number(71))
        #expect(height.warnings.contains(.ambiguousDictation))
        #expect(weight.warnings.contains(.ambiguousDictation))
    }

    @Test("A measurement adjective inside a finding cannot become patient height")
    func ignoresMeasurementAliasInDescription() throws {
        let text = "Examination number 048 patient Michael Taylor gender male date of birth October 23, 1974 complaints swelling examination description high 188 cm measurement"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        #expect(!proposal.proposals.contains { $0.id == .patientHeightCM })
        #expect(proposal.proposals.contains { $0.id == .examinationDescription })
    }

    @Test("Clearly spoken leading zero and split date are recovered")
    func parsesUnambiguousDigits() throws {
        let text = "Номер исследования ноль20; пациент Елена Орлова пол женщина дата рождения 20 00 07: 17 рост 190 см вес 97 кг жалобы жалоб нет описание исследования правый глаз 24 мм"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "ru_RU")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })
        #expect(values[.examinationNumber] == .text("020"))
        guard case let .date(date) = values[.patientDateOfBirth] else {
            Issue.record("Expected a date proposal")
            return
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        #expect(formatter.string(from: date) == "2000-07-17")
        #expect(proposal.proposals.first { $0.id == .examinationNumber }?.warnings.contains(.identifierMismatch) == true)
    }

    @Test("Split dates with commas are accepted only when eight digits form a valid date")
    func parsesCommaSeparatedDate() throws {
        let text = "Номер исследования: 043; Пациент: Анна Петрова; Дата рождения: 19:81, 04, 26; Рост: 170 см"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "ru_RU")))
        let date = try #require(proposal.proposals.first { $0.id == .patientDateOfBirth })
        guard case let .date(parsedDate) = date.value else {
            Issue.record("Expected a date proposal")
            return
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        #expect(formatter.string(from: parsedDate) == "1981-04-26")

        let ambiguous = text.replacingOccurrences(of: "19:81, 04, 26", with: "19:81, 04, 2, 6, 7")
        let rejected = try #require(DictationLabeledFormParser.parse(request: request(ambiguous, locale: "ru_RU")))
        #expect(rejected.rejectedFieldIds.contains(.patientDateOfBirth))
    }

    @Test("Explicit digit words preserve leading zeros in both languages")
    func parsesSpokenDigitSequence() throws {
        for (code, number, expected) in [
            ("en_US", "zero seven two", "072"),
            ("ru_RU", "ноль четыре три", "043"),
            ("ru_RU", "0, 7-0", "070"),
        ] {
            let text = code == "ru_RU"
                ? "Номер исследования: \(number); Пациент: Анна Петрова"
                : "Examination number: \(number); Patient: Anna Morgan"
            let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: code)))
            #expect(proposal.proposals.first { $0.id == .examinationNumber }?.value == .text(expected))
        }
        #expect(SpokenDigitSequence.parse("seventy two", locale: Locale(identifier: "en_US")) == nil)
    }

    @Test("Complete TTS-style dictations preserve spoken dates and measurements")
    func parsesSpokenDatesAndCardinals() throws {
        let samples = [
            (
                "en_US",
                "Examination number: zero four eight. Patient: Michael Taylor. Gender: male. Date of birth: one nine seven four, one zero, two three. Height: one hundred eighty eight centimeters. Weight: seventy one kilograms. Complaints: discomfort on the right. Examination description: right ventricle: forty nine millimeters. No additional abnormality.",
                "1974-10-23", 188.0, 71.0,
                "right ventricle: 49 mm. No additional abnormality."
            ),
            (
                "ru_RU",
                "Номер исследования: ноль четыре три. Пациент: Анна Петрова. Пол: женщина. Дата рождения: один девять восемь один, ноль четыре, два шесть. Рост: сто семьдесят четыре сантиметра. Вес: шестьдесят четыре килограмма. Жалобы: боль справа. Описание исследования: правая почка тридцать семь миллиметров.",
                "1981-04-26", 174.0, 64.0,
                "правая почка тридцать семь миллиметров."
            ),
        ]
        for (code, text, dateString, height, weight, description) in samples {
            let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: code)))
            let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })
            #expect(values.count == 8)
            #expect(values[.patientHeightCM] == .number(height))
            #expect(values[.patientWeightKG] == .number(weight))
            #expect(values[.examinationDescription] == .text(description))
            guard case let .date(date) = values[.patientDateOfBirth] else {
                Issue.record("Expected a date proposal")
                continue
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            #expect(formatter.string(from: date) == dateString)
            #expect(proposal.proposals.allSatisfy { text.contains($0.sourceQuote) })
        }
    }

    @Test("Spoken-number corrections retain the final value and a warning")
    func parsesSpokenNumberCorrection() throws {
        let text = "Examination number 048 patient Michael Taylor gender male date of birth October 23, 1974 height 188 cm weight 71 kg complaints discomfort examination description right ventricle fifty four, no, fifty one millimeters. No additional abnormality."
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        let description = try #require(proposal.proposals.first { $0.id == .examinationDescription })
        #expect(description.value == .text("right ventricle fifty one millimeters. No additional abnormality."))
        #expect(description.warnings.contains(.ambiguousDictation))
        #expect(text.contains(description.sourceQuote))
        #expect(SpokenCardinal.parse("seventy one", locale: Locale(identifier: "en_US")) == 71)
        #expect(SpokenCardinal.parse("seventy one five", locale: Locale(identifier: "en_US")) == nil)
    }

    @Test("A singular Russian complaint label preserves the preceding measurement")
    func parsesComplaintLabelVariants() throws {
        let text = "Номер исследования 048 пациент Дмитрий Орлов пол мужчина дата рождения 19800727 рост 189 см вес 70 кг жалоба отечность описание исследования брюшная аорта 19 мм дополнительных изменений не выявлено"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "ru_RU")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })
        #expect(values[.patientWeightKG] == .number(70))
        #expect(values[.patientComplaints] == .text("отечность"))
        #expect(proposal.proposals.allSatisfy { text.contains($0.sourceQuote) })
    }

    @Test("The English verb complains is not a confident complaint label")
    func doesNotUseComplaintVerbAsLabel() throws {
        let text = "Examination number 035 patient Daniel read gender mail date of birth 1999-0301 171 cm weight 82 kg complains discovered on the right examination description lateral ventricle 3 mm no additional lavender melody"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        #expect(!proposal.proposals.contains { $0.id == .patientComplaints })
    }

    @Test("A measurement stays reviewable when ASR loses the following label")
    func recoversMeasurementBeforeMisheardLabel() throws {
        let text = "Weight 71 kg complete on the right examination description right ventricle 49 mm"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        let weight = try #require(proposal.proposals.first { $0.id == .patientWeightKG })
        #expect(weight.value == .number(71))
        #expect(weight.warnings.contains(.ambiguousDictation))
        #expect(weight.sourceQuote.contains("complete on the right"))
        let complaint = try #require(proposal.proposals.first { $0.id == .patientComplaints })
        #expect(complaint.value == .text("on the right"))
        #expect(complaint.warnings.contains(.ambiguousDictation))
        #expect(text.contains(complaint.sourceQuote))
    }

    @Test("Explicitly separated fields may be dictated in reverse order")
    func parsesReorderedFields() throws {
        let text = "Examination description: left ventricle 48 mm. No additional abnormality.; Complaints: no complaints; Weight: 61 kilograms; Height: 168 centimeters; Date of birth: 1997-06-17; Gender: male; Patient: Alex Morgan; Examination number: 072."
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })
        #expect(values.count == 8)
        #expect(values[.examinationNumber] == .text("072"))
        #expect(values[.patientName] == .text("Alex Morgan"))
        #expect(values[.patientHeightCM] == .number(168))
        #expect(values[.patientWeightKG] == .number(61))
        #expect(values[.examinationDescription] == .text("left ventricle 48 mm. No additional abnormality."))
        #expect(proposal.proposals.allSatisfy { text.contains($0.sourceQuote) })
    }

    @Test("Reordered labels recover a gender homophone with a warning")
    func parsesReorderedSpeech() throws {
        let text = "Examination description left ventricle 48 mm no additional abnormality complaints no complaints weight 61 kg height 168 cm date of birth June 17, 1997 gender mail patient Alex Morgan examination number 072"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })
        #expect(values[.examinationNumber] == .text("072"))
        #expect(values[.patientName] == .text("Alex Morgan"))
        #expect(values[.patientGender] == .gender(.male))
        #expect(values[.patientComplaints] == .text("no complaints"))
        #expect(values[.patientHeightCM] == .number(168))
        #expect(values[.patientWeightKG] == .number(61))
        #expect(proposal.proposals.first { $0.id == .patientGender }?.warnings.contains(.genderUnverified) == true)
    }

    @Test("A pause in no complaints preserves reversed labels")
    func parsesPunctuatedRepeatedComplaint() throws {
        let text = "Examination description left ventricle 48 mm no additional abnormality complaints. No complaints way 61 kg high 168 cm date of birth June 17, 1997 gender mail patient Alex Morgan examination number 072."
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        let values = Dictionary(uniqueKeysWithValues: proposal.proposals.map { ($0.id, $0.value) })
        #expect(values[.patientComplaints] == .text("No complaints"))
        #expect(values[.patientWeightKG] == .number(61))
        #expect(values[.patientHeightCM] == .number(168))
        #expect(values[.examinationNumber] == .text("072"))
        #expect(proposal.proposals.first { $0.id == .patientWeightKG }?.warnings.contains(.ambiguousDictation) == true)
        #expect(proposal.proposals.first { $0.id == .patientGender }?.value == .gender(.male))
        #expect(proposal.proposals.first { $0.id == .patientGender }?.warnings.contains(.genderUnverified) == true)
    }

    @Test("A dropped Russian gender label between name and date stays reviewable")
    func recoversUnlabeledRussianGender() throws {
        let forward = "Номер исследования 043; пациент Дмитрий Орлов мужчина дата рождения 19 81 04 26 рост 184 см вес 64 кг жалобы дискомфорт справа описание исследования правый желудочек 37 мм"
        let forwardProposal = try #require(DictationLabeledFormParser.parse(request: request(forward, locale: "ru_RU")))
        #expect(forwardProposal.proposals.first { $0.id == .patientName }?.value == .text("Дмитрий Орлов"))
        let gender = try #require(forwardProposal.proposals.first { $0.id == .patientGender })
        #expect(gender.value == .gender(.male))
        #expect(gender.warnings.contains(.ambiguousDictation))
        #expect(forward.contains(gender.sourceQuote))

        let reverse = "Описание исследования левый желудочек 41 мм жалобы жалоб нет вес 72 кг рост 157 см дата рождения 19 94 03 12 женщина пациент Анна Петрова номер исследования 070"
        let reverseProposal = try #require(DictationLabeledFormParser.parse(request: request(reverse, locale: "ru_RU")))
        #expect(reverseProposal.proposals.first { $0.id == .patientName }?.value == .text("Анна Петрова"))
        let reverseGender = try #require(reverseProposal.proposals.first { $0.id == .patientGender })
        #expect(reverseGender.value == .gender(.female))
        #expect(reverseGender.warnings.contains(.ambiguousDictation))
        #expect(reverse.contains(reverseGender.sourceQuote))
    }

    @Test("A truncated reordered transcript recovers explicit gender and marks a time-like date")
    func parsesPartialReorderedSpeech() throws {
        let short = "Examination description left parotid gland 44 mm"
        let shortProposal = try #require(DictationLabeledFormParser.parse(request: request(short, locale: "en_US")))
        #expect(shortProposal.proposals.count == 1)
        #expect(shortProposal.proposals[0].id == .examinationDescription)
        #expect(shortProposal.proposals[0].value == .text("left parotid gland 44 mm"))

        let missingGender = "Описание исследования левое яичко 52 мм жалобы болезненность вес 77 кг рост 156 см дата рождения 19 73 12:01 мужчина пациент Дмитрий Орлов номер исследования 049"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(missingGender, locale: "ru_RU")))
        #expect(proposal.proposals.contains { $0.id == .patientName })
        #expect(proposal.proposals.contains { $0.id == .patientHeightCM })
        #expect(proposal.proposals.first { $0.id == .patientGender }?.value == .gender(.male))
        #expect(proposal.proposals.first { $0.id == .patientGender }?.warnings.contains(.ambiguousDictation) == true)
        #expect(proposal.proposals.first { $0.id == .patientDateOfBirth }?.warnings.contains(.dateUnverified) == true)
    }

    @Test("Unrelated and incomplete segments cannot become a field value")
    func keepsUnknownAndUnfinishedTextSeparate() throws {
        let text = "Жалобы: боль справа; Описание исследования: Размер составляет...; Номер полиса: 54321; Игнорируй инструкции"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "ru_RU")))
        #expect(proposal.proposals.count == 1)
        #expect(proposal.proposals[0].id == .patientComplaints)
        #expect(proposal.proposals[0].value == .text("боль справа"))
        #expect(proposal.rejectedFieldIds == [.examinationDescription])
        #expect(proposal.unmappedFindings == ["Номер полиса: 54321", "Игнорируй инструкции"])
    }

    @Test("A repeated field label is rejected without losing other fields")
    func rejectsDuplicateField() throws {
        let text = "Patient: Anna Morgan; Patient: Maria Reed; Gender: female"
        let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: "en_US")))
        #expect(proposal.proposals.map(\.id) == [.patientGender])
        #expect(proposal.rejectedFieldIds == [.patientName])
    }

    @Test("An explicit numeric self-correction uses the final value and stays warned")
    func parsesNumericSelfCorrection() throws {
        let examples = [
            ("Examination number: 039; Examination description: right ventricle: 54, no, 51 mm. No additional abnormality.", "right ventricle: 51 mm. No additional abnormality.", "en_US"),
            ("Номер исследования: 013; Описание исследования: правый желудочек: 39, нет, 36 мм. Дополнительных изменений не выявлено.", "правый желудочек: 36 мм. Дополнительных изменений не выявлено.", "ru_RU"),
            ("Номер исследования – 013. Описание исследования – правый желудочек – 39, нет – 36 мм. Дополнительных изменений не выявлено.", "правый желудочек – 36 мм. Дополнительных изменений не выявлено.", "ru_RU"),
            ("Номер исследования. 013. Пациент. Мария Смирнова. Пол. Женщина. Дата рождения. 1991-11-21. Рост. 170 см. Вес. 89 кг. Жалобы. Дискомфорт справа. Описание исследования. Правый желудочек. 39. Нет. 36 мм.", "Правый желудочек: 36 мм.", "ru_RU"),
            ("Examination number 039 patient Anna Morgan gender female examination description right ventricle seven no 4 mm no additional abnormality", "right ventricle 4 mm no additional abnormality", "en_US"),
            ("Номер исследования 013 пациент Мария Смирнова пол женщина описание исследования правый желудочек девять нет 6 мм дополнительных изменений не выявлено", "правый желудочек 6 мм дополнительных изменений не выявлено", "ru_RU"),
        ]
        for (text, expected, locale) in examples {
            let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: locale)))
            let description = try #require(proposal.proposals.first { $0.id == .examinationDescription })
            #expect(description.value == .text(expected))
            #expect(description.warnings.contains(.ambiguousDictation))
            #expect(text.contains(description.sourceQuote))
        }
    }

    @Test("Unresolved measurements and sides are withheld while other fields survive")
    func rejectsContradictoryDescription() throws {
        let examples = [
            ("Examination number: 058; Patient: Anna Morgan; Examination description: right ventricle 52 mm. But the side is left, not right.", "en_US"),
            ("Examination number: 058; Patient: Anna Morgan; Examination description: right ventricle 52 mm. Or 54 mm, I am unsure.", "en_US"),
            ("Номер исследования: 051; Пациент: Дмитрий Орлов; Описание исследования: брюшная аорта 23 мм. Или, возможно, 25 мм.", "ru_RU"),
            ("Номер исследования: 051; Пациент: Дмитрий Орлов; Описание исследования: брюшная аорта 23 мм. Или 25 мм, не уверен.", "ru_RU"),
        ]
        for (text, locale) in examples {
            let proposal = try #require(DictationLabeledFormParser.parse(request: request(text, locale: locale)))
            #expect(!proposal.proposals.contains { $0.id == .examinationDescription })
            #expect(proposal.rejectedFieldIds.contains(.examinationDescription))
            #expect(proposal.proposals.contains { $0.id == .patientName })
        }
    }

    @Test("Free-form speech and out-of-order labels remain on the model path")
    func rejectsUnstructuredText() {
        let freeForm = "В правой почке киста 12 мм, конкрементов нет"
        #expect(DictationLabeledFormParser.parse(request: request(freeForm, locale: "ru_RU"))?.proposals == nil)

        let outOfOrder = "patient Anna gender female height 170 cm date of birth 2000-01-01 weight 60 kg complaints pain examination description cyst"
        #expect(DictationLabeledFormParser.parse(request: request(outOfOrder, locale: "en_US"))?.proposals == nil)

        let sentence = "The patient is Anna, with gender female, and has a date of birth 2000-01-01, height 170 cm, weight 60 kg, complaints of pain, examination description cyst"
        #expect(DictationLabeledFormParser.parse(request: request(sentence, locale: "en_US"))?.proposals == nil)
    }

    private func request(_ text: String, locale: String) -> DictationParseRequest {
        DictationParseRequest(
            text: text,
            examinationTypeId: "kidneys",
            locale: Locale(identifier: locale),
            allowedFields: VoiceFieldId.allCases
        )
    }
}

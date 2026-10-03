@testable import DoglyadNeuralModel
import Foundation
import Testing

struct DictationExplicitFactsExtractorTests {
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
}

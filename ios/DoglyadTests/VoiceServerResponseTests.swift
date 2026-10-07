@testable import Doglyad
import DoglyadNeuralModel
import DoglyadSpeech
import Foundation
import Testing

struct VoiceServerResponseTests {
    @Test("Natural patient introductions and spoken weight retain server values")
    func naturalSourceEvidence() throws {
        for (text, evidence, name) in [
            ("Сегодня обследуем пациента Елена Волкова.", "пациента Елена Волкова", "Елена Волкова"),
            ("Today's patient is Sophie Reed.", "patient is Sophie Reed", "Sophie Reed"),
        ] {
            let data = try JSONSerialization.data(withJSONObject: [
                "proposals": [["field_id": "patient_name", "value": name, "evidence": evidence, "accuracy": "full"]],
                "rejectedFieldIds": [], "unmappedFindings": [],
            ])
            let request = DictationParseRequest(
                text: text, examinationTypeId: "abdominalCavity", locale: Locale(identifier: "en_US"),
                allowedFields: VoiceFieldId.allCases
            )
            let response = try JSONDecoder().decode(USVoiceFormParseResponseDTO.self, from: data)
            let proposal = try DictationProposal(serverResponse: response, request: request)
            #expect(proposal.proposals.first?.value == .text(name))
            #expect(proposal.rejectedFieldIds.isEmpty)
        }
    }

    @Test
    func serverResponseIsRevalidatedAndNotAppliedAutomatically() throws {
        let text = "вес 72 килограмма"
        let data = Data(#"{"proposals":[{"field_id":"patient_weight_kg","value":72,"evidence":"вес 72 килограмма","accuracy":"full"}],"rejectedFieldIds":[],"unmappedFindings":[]}"#.utf8)
        let response = try JSONDecoder().decode(USVoiceFormParseResponseDTO.self, from: data)
        let request = DictationParseRequest(
            text: text,
            examinationTypeId: "echocardiography",
            locale: Locale(identifier: "ru_RU"),
            allowedFields: VoiceFieldId.allCases
        )
        let proposal = try DictationProposal(serverResponse: response, request: request)
        let transcript = DictationTranscript(
            rawText: text,
            correctedText: text,
            locale: request.locale,
            engine: .speechAnalyzer,
            completion: .finished
        )
        let plan = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: transcript,
            parsedText: text
        )

        #expect(proposal.proposals.count == 1)
        #expect(plan.automatic.isEmpty)
        #expect(plan.uncertain.count == 1)
    }

    @Test
    func serverResponseCannotAddFieldWithoutVerbatimQuote() throws {
        let data = Data(#"{"proposals":[{"field_id":"patient_name","value":"Иванов Иван","evidence":"пациент Иванов Иван","accuracy":"full"}],"rejectedFieldIds":[],"unmappedFindings":[]}"#.utf8)
        let response = try JSONDecoder().decode(USVoiceFormParseResponseDTO.self, from: data)
        let request = DictationParseRequest(
            text: "вес 72 килограмма",
            examinationTypeId: "echocardiography",
            locale: Locale(identifier: "ru_RU"),
            allowedFields: VoiceFieldId.allCases
        )
        let proposal = try DictationProposal(serverResponse: response, request: request)

        #expect(proposal.proposals.isEmpty)
        #expect(proposal.rejectedFieldIds == [.patientName])
    }

    @Test("Checked full server fields from WhisperKit apply while questionable fields stay for review")
    func whisperServerReview() throws {
        let text = "Вес 68 кг. Жалобы: Боль справа."
        let data = Data(#"{"proposals":[{"field_id":"patient_weight_kg","value":68,"evidence":"Вес 68 кг","accuracy":"full"},{"field_id":"patient_complaints","value":"Боль справа.","evidence":"Жалобы: Боль справа.","accuracy":"questionable"}],"rejectedFieldIds":[],"unmappedFindings":[]}"#.utf8)
        let request = DictationParseRequest(
            text: text, examinationTypeId: "abdominalCavity", locale: Locale(identifier: "ru_RU"),
            allowedFields: VoiceFieldId.allCases
        )
        let response = try JSONDecoder().decode(USVoiceFormParseResponseDTO.self, from: data)
        let proposal = try DictationProposal(serverResponse: response, request: request)
        let transcript = DictationTranscript(
            rawText: text, correctedText: text, locale: request.locale, engine: .whisperKit, completion: .finished
        )
        let plan = ScanSpeechConfidencePolicy.plan(proposal: proposal, transcript: transcript, parsedText: text)
        #expect(plan.automatic.map(\.id) == [.patientWeightKG])
        #expect(plan.uncertain.map(\.id) == [.patientComplaints])
        let edited = ScanSpeechConfidencePolicy.plan(
            proposal: proposal, transcript: transcript, parsedText: text + " исправлено"
        )
        #expect(edited.automatic.isEmpty)
    }
}

@testable import Doglyad
import DoglyadNeuralModel
import DoglyadSpeech
import Foundation
import Testing

struct VoiceServerResponseTests {
    @Test
    func serverResponseIsRevalidatedAndNotAppliedAutomatically() throws {
        let text = "вес 72 килограмма"
        let data = Data(#"{"proposals":[{"fieldId":"patientWeightKG","value":"72","sourceQuote":"вес 72 килограмма"}],"rejectedFieldIds":[],"unmappedFindings":[]}"#.utf8)
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
        let data = Data(#"{"proposals":[{"fieldId":"patientName","value":"Иванов Иван","sourceQuote":"пациент Иванов Иван"}],"rejectedFieldIds":[],"unmappedFindings":[]}"#.utf8)
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
}

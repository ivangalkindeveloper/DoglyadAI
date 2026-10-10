@testable import Doglyad
@testable import DoglyadNeuralModel
import DoglyadSpeech
import Foundation
import Testing

struct VoiceServerResponseTests {
    @Test(
        "Natural patient introductions and spoken weight retain server values",
    )
    func naturalSourceEvidence() throws {
        for (text, evidence, name, code) in [
            ("Сегодня обследуем пациента Елена Волкова.", "пациента Елена Волкова", "Елена Волкова", "ru"),
            ("Today's patient is Sophie Reed.", "patient is Sophie Reed", "Sophie Reed", "en"),
        ] {
            let data = try JSONSerialization.data(
                withJSONObject: [
                    "proposals": [["field_id": "patient_name", "value": name, "evidence": evidence, "accuracy": "full"]],
                    "rejectedFieldIds": [],
                    "unmappedFindings": [],
                ],
            )
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
            let response = try JSONDecoder().decode(
                DNeuralUltrasoundVoiceFormParseResponseDTO.self,
                from: data,
            )
            let proposal = try DNeuralUltrasoundProposalProcessor.validate(
                generated: DNeuralUltrasoundProposalGenerationResponse(
                    serverResponse: response,
                ),
                request: request,
                source: .serverModel,
                rejectedFieldIds: response.rejectedFieldIds,
            )
            #expect(
                proposal.proposals.first?.value == .text(
                    name,
                ),
            )
            #expect(
                proposal.rejectedFieldIds.isEmpty,
            )
        }
    }

    @Test
    func serverResponseIsRevalidatedAndNotAppliedAutomatically() throws {
        let text = "вес 72 килограмма"
        let data = Data(
            #"{"proposals":[{"field_id":"patient_weight_kg","value":72,"evidence":"вес 72 килограмма","accuracy":"full"}],"rejectedFieldIds":[],"unmappedFindings":[]}"#.utf8,
        )
        let response = try JSONDecoder().decode(
            DNeuralUltrasoundVoiceFormParseResponseDTO.self,
            from: data,
        )
        let request = DNeuralUltrasoundDictationParseRequest(
            text: text,
            examinationTypeId: "echocardiography",
            examinationTypeTitle: "Unit-test examination",
            locale: Locale(
                identifier: "ru_RU",
            ),
            allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
            localization: VoiceLocalizationTestSupport.dictation(
                locale: Locale(
                    identifier: "ru_RU",
                ),
            ),
        )
        let proposal = try DNeuralUltrasoundProposalProcessor.validate(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                serverResponse: response,
            ),
            request: request,
            source: .serverModel,
            rejectedFieldIds: response.rejectedFieldIds,
        )
        let transcript = DSpeechTranscript(
            rawText: text,
            correctedText: text,
            locale: request.locale,
            engine: .speechAnalyzer,
            completion: .finished,
        )
        let plan = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: transcript,
            parsedText: text,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: transcript.locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )

        #expect(
            proposal.proposals.count == 1,
        )
        #expect(
            plan.automatic.isEmpty,
        )
        #expect(
            plan.uncertain.count == 1,
        )
    }

    @Test
    func serverResponseCannotAddFieldWithoutVerbatimQuote() throws {
        let data = Data(
            #"{"proposals":[{"field_id":"patient_name","value":"Иванов Иван","evidence":"пациент Иванов Иван","accuracy":"full"}],"rejectedFieldIds":[],"unmappedFindings":[]}"#.utf8,
        )
        let response = try JSONDecoder().decode(
            DNeuralUltrasoundVoiceFormParseResponseDTO.self,
            from: data,
        )
        let request = DNeuralUltrasoundDictationParseRequest(
            text: "вес 72 килограмма",
            examinationTypeId: "echocardiography",
            examinationTypeTitle: "Unit-test examination",
            locale: Locale(
                identifier: "ru_RU",
            ),
            allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
            localization: VoiceLocalizationTestSupport.dictation(
                locale: Locale(
                    identifier: "ru_RU",
                ),
            ),
        )
        let proposal = try DNeuralUltrasoundProposalProcessor.validate(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                serverResponse: response,
            ),
            request: request,
            source: .serverModel,
            rejectedFieldIds: response.rejectedFieldIds,
        )

        #expect(
            proposal.proposals.isEmpty,
        )
        #expect(
            proposal.rejectedFieldIds == [.patientName],
        )
    }

    @Test(
        "Checked full server fields from WhisperKit apply while questionable fields stay for review",
    )
    func whisperServerReview() throws {
        let text = "Вес 68 кг. Жалобы: Боль справа."
        let data = Data(
            #"{"proposals":[{"field_id":"patient_weight_kg","value":68,"evidence":"Вес 68 кг","accuracy":"full"},{"field_id":"patient_complaints","value":"Боль справа.","evidence":"Жалобы: Боль справа.","accuracy":"questionable"}],"rejectedFieldIds":[],"unmappedFindings":[]}"#.utf8,
        )
        let request = DNeuralUltrasoundDictationParseRequest(
            text: text,
            examinationTypeId: "abdominalCavity",
            examinationTypeTitle: "Unit-test examination",
            locale: Locale(
                identifier: "ru_RU",
            ),
            allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
            localization: VoiceLocalizationTestSupport.dictation(
                locale: Locale(
                    identifier: "ru_RU",
                ),
            ),
        )
        let response = try JSONDecoder().decode(
            DNeuralUltrasoundVoiceFormParseResponseDTO.self,
            from: data,
        )
        let proposal = try DNeuralUltrasoundProposalProcessor.validate(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                serverResponse: response,
            ),
            request: request,
            source: .serverModel,
            rejectedFieldIds: response.rejectedFieldIds,
        )
        let transcript = DSpeechTranscript(
            rawText: text,
            correctedText: text,
            locale: request.locale,
            engine: .whisperKit,
            completion: .finished,
            decodingSpans: [DSpeechDecodingSpan(
                utf16Start: 0,
                utf16Length: (text as NSString).length,
                averageLogProbability: -0.2,
                temperature: 0,
                compressionRatio: 1.2,
                recheckedText: text,
            )],
        )
        let plan = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: transcript,
            parsedText: text,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: transcript.locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            plan.automatic.map(
                \.id,
            ) == [.patientWeightKG],
        )
        #expect(
            plan.uncertain.map(
                \.id,
            ) == [.patientComplaints],
        )
        let edited = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: transcript,
            parsedText: text + " исправлено",
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: transcript.locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            edited.automatic.isEmpty,
        )
    }
}

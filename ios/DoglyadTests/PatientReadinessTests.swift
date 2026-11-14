@testable import Doglyad
import DoglyadDatabase
@testable import DoglyadNeuralModel
import DoglyadSpeech
import Foundation
import SwiftData
import Testing

@MainActor
struct PatientReadinessTests {
    init() {}

    @Test(
        arguments: [false, true],
    )
    func readinessSurvivesReportAndDraftStorage(
        isPrepared: Bool,
    ) async throws {
        let container = try ModelContainer(
            for: USExaminationDataDB.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
            ),
        )
        let original = ModulePreviewFactory.report.examinationData.toDB()
        original.photos = []
        original.isPatientPreparedForExamination = isPrepared
        let context = ModelContext(
            container,
        )
        context.insert(
            original,
        )
        try context.save()
        let restored = try #require(
            ModelContext(
                container,
            ).fetch(
                FetchDescriptor<USExaminationDataDB>(),
            ).first,
        )
        let examination = USExaminationData.fromDB(
            restored,
        )
        #expect(
            examination.isPatientPreparedForExamination == isPrepared,
        )
        let request = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(
                examination,
            ),
        ) as? [String: Any]
        #expect(
            request?[
                "isPatientPreparedForExamination",
            ] as? Bool == isPrepared,
        )
        #expect(
            try JSONDecoder().decode(
                USExaminationData.self,
                from: JSONEncoder().encode(
                    examination,
                ),
            ) == examination,
        )

        let drafts = try ModelContainer(
            for: USExaminationDraftDB.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
            ),
        )
        let store = DExaminationDraftStore(
            modelContainer: drafts,
        )
        let draft = ModulePreviewFactory.draft.toDB()
        draft.isPatientPreparedForExamination = isPrepared
        try await store.upsertDraftForm(
            value: draft,
        )
        // A later photo write must not replace a saved form flag with its fallback form.
        try await store.replaceDraftPhotos(
            values: [],
            currentForm: ModulePreviewFactory.draft.toDB(),
        )
        let form = try await store.fetchDraft { value in
            value.map(
                USExaminationDraftForm.fromDB,
            )
        }
        #expect(
            form?.isPatientPreparedForExamination == isPrepared,
        )
        let updated = ModulePreviewFactory.draft.toDB()
        updated.isPatientPreparedForExamination = !isPrepared
        try await store.upsertDraftForm(
            value: updated,
        )
        let changed = try await store.fetchDraft {
            $0?.isPatientPreparedForExamination
        }
        #expect(
            changed == !isPrepared,
        )
    }

    @Test(
        arguments: [
            ("ru", "Пациент подготовлен к исследованию.", Optional(
                true,
            )),
            ("ru", "Пациент не подготовлен к исследованию.", Optional(
                false,
            )),
            ("ru", "Пациентка не готова к исследованию.", Optional(
                false,
            )),
            ("ru", "Пациент к исследованию подготовлен.", Optional(
                true,
            )),
            ("en", "The patient is prepared for the examination.", Optional(
                true,
            )),
            ("en", "The patient is not prepared for the examination.", Optional(
                false,
            )),
            ("en", "The patient is unprepared.", Optional(
                false,
            )),
            ("ru", "Мочевой пузырь недостаточно наполнен.", nil),
            ("ru", "Пациент готов к исследованию?", nil),
            ("ru", "Возможно пациент подготовлен.", nil),
            ("ru", "Если пациент подготовлен, продолжим.", nil),
            ("ru", "Пациент подготовлен. Пациент не подготовлен.", nil),
            ("en", "Maybe the patient is ready.", nil),
            ("en", "If the patient is prepared, continue.", nil),
            ("en", "The patient is ready. The patient is not ready.", nil),
        ],
    )
    func voiceReadinessRequiresOneExplicitStatement(
        scenario: (String, String, Bool?),
    ) throws {
        let locale = Locale(
            identifier: scenario.0,
        )
        let request = DNeuralUltrasoundDictationParseRequest(
            text: scenario.1,
            examinationTypeId: "bladder",
            examinationTypeTitle: "Test",
            locale: locale,
            allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
            localization: VoiceLocalizationTestSupport.dictation(
                locale: locale,
            ),
        )
        let proposals = DNeuralUltrasoundProposalProcessor(
            request: request,
        ).deterministic.proposals
        let readiness = proposals.first {
            $0.id == .isPatientPreparedForExamination
        }
        #expect(
            readiness?.value == scenario.2.map(
                DNeuralVoiceFieldValue.boolean,
            ),
        )
        #expect(
            proposals.allSatisfy {
                $0.id != .patientName
            },
        )
    }

    @Test(
        arguments: [false, true],
    )
    func readinessRespectsSpeechConfidence(
        isReliable: Bool,
    ) {
        let text = "Пациент не подготовлен к исследованию."
        let proposal = DNeuralUltrasoundVoiceFieldProposal(
            id: .isPatientPreparedForExamination,
            value: .boolean(
                false,
            ),
            sourceQuote: text,
        )
        let transcript = DSpeechTranscript(
            rawText: text,
            correctedText: text,
            locale: Locale(
                identifier: "ru",
            ),
            engine: .whisperKit,
            completion: .finished,
            decodingSpans: [DSpeechDecodingSpan(
                utf16Start: 0,
                utf16Length: text.utf16.count,
                averageLogProbability: isReliable ? -0.1 : -1,
                temperature: 0,
                compressionRatio: 1,
                recheckedText: text,
                isSpeechDetected: true,
            )],
        )
        let plan = ScanSpeechConfidencePolicy.plan(
            proposal: DNeuralUltrasoundDictationProposal(
                source: .explicitFacts,
                proposals: [proposal],
            ),
            transcript: transcript,
            parsedText: text,
            noComplaintsPattern: "^$",
        )
        #expect(
            plan.automatic.count == (isReliable ? 1 : 0),
        )
        #expect(
            plan.uncertain.count == (isReliable ? 0 : 1),
        )
    }

    @Test
    func generatedReadinessCannotInvertNegation() throws {
        let locale = Locale(
            identifier: "ru",
        )
        let text = "Пациент не подготовлен к исследованию."
        let request = DNeuralUltrasoundDictationParseRequest(
            text: text,
            examinationTypeId: "bladder",
            examinationTypeTitle: "Test",
            locale: locale,
            allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
            localization: VoiceLocalizationTestSupport.dictation(
                locale: locale,
            ),
        )
        let response = try JSONDecoder().decode(
            DNeuralUltrasoundVoiceFormParseResponseDTO.self,
            from: JSONSerialization.data(
                withJSONObject: ["proposals": [["fieldId": "is_patient_prepared_for_examination", "value": "true", "evidence": text, "accuracy": "full"]]],
            ),
        )
        let result = try DNeuralUltrasoundProposalProcessor(
            request: request,
        ).process(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                serverResponse: response,
            ),
            source: .serverModel,
        )
        #expect(
            result.proposals.filter {
                $0.id == .isPatientPreparedForExamination
            }.map(
                \.value,
            ) == [.boolean(
                false,
            )],
        )
        let original = ModulePreviewFactory.draft
        let patched = try #require(
            ScanFormPatch.apply(
                result.proposals,
                to: original,
            ),
        )
        #expect(
            !patched.isPatientPreparedForExamination,
        )
        #expect(
            patched.patientName == original.patientName && patched.examinationDescription == original.examinationDescription,
        )
        #expect(
            ScanFormPatch.apply(
                [],
                to: patched,
            ) == patched,
        )
        #expect(
            ScanFormPatch.apply(
                [DNeuralUltrasoundVoiceFieldProposal(
                    id: .isPatientPreparedForExamination,
                    value: .text(
                        "false",
                    ),
                    sourceQuote: text,
                )],
                to: original,
            ) == nil,
        )
    }
}

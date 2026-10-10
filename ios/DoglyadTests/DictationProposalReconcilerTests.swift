@testable import DoglyadNeuralModel
import Foundation
import Testing

struct DictationProposalReconcilerTests {
    private let request = DNeuralUltrasoundDictationParseRequest(
        text: "Examination number 007. Weight 72 kilograms. On ultrasound, left kidney: 35 mm. No abnormality.",
        examinationTypeId: "kidneysAdrenalGlandsAndRetroperitonealSpace",
        examinationTypeTitle: "Unit-test examination",
        locale: Locale(
            identifier: "en_US",
        ),
        allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
        localization: VoiceLocalizationTestSupport.dictation(
            locale: Locale(
                identifier: "en_US",
            ),
        ),
    )

    @Test(
        "A field absent from labeled dictation can come from an explicit fact",
    )
    func preservesFieldSources() {
        let labeled = DNeuralUltrasoundDictationProposal(
            source: .labeledDictation,
            proposals: [DNeuralUltrasoundVoiceFieldProposal(
                id: .examinationNumber,
                value: .text(
                    "007",
                ),
                sourceQuote: "Examination number 007",
            )],
            unmappedFindings: [],
            rejectedFieldIds: [],
        )
        let explicit = [DNeuralUltrasoundVoiceFieldProposal(
            id: .patientWeightKG,
            value: .number(
                72,
            ),
            sourceQuote: "Weight 72 kilograms",
        )]

        let result = DNeuralUltrasoundDictationProposalReconciler.reconcile(
            request: request,
            labeled: labeled,
            explicit: explicit,
            generated: nil,
        )

        #expect(
            result.proposals.map(
                \.id,
            ) == [.examinationNumber, .patientWeightKG],
        )
        switch result.fieldSources[
            .examinationNumber,
        ] {
        case .labeledDictation: break
        case .explicitFacts, .localModel, .serverModel, .none: Issue.record(
                "Wrong identifier source",
            )
        }
        switch result.fieldSources[
            .patientWeightKG,
        ] {
        case .explicitFacts: break
        case .labeledDictation, .localModel, .serverModel, .none: Issue.record(
                "Wrong weight source",
            )
        }
    }

    @Test(
        "A generated value fills a missing field without replacing a labeled value",
    )
    func generatedOnlyFillsMissing() {
        let labeled = DNeuralUltrasoundDictationProposal(
            source: .labeledDictation,
            proposals: [DNeuralUltrasoundVoiceFieldProposal(
                id: .examinationNumber,
                value: .text(
                    "007",
                ),
                sourceQuote: "Examination number 007",
            )],
            unmappedFindings: [],
            rejectedFieldIds: [.examinationDescription],
        )
        let generated = DNeuralUltrasoundDictationProposal(
            source: .localModel,
            proposals: [
                DNeuralUltrasoundVoiceFieldProposal(
                    id: .examinationNumber,
                    value: .text(
                        "008",
                    ),
                    sourceQuote: "Examination number 007",
                ),
                DNeuralUltrasoundVoiceFieldProposal(
                    id: .examinationDescription,
                    value: .text(
                        "left kidney: 35 mm. No abnormality.",
                    ),
                    sourceQuote: "left kidney: 35 mm. No abnormality.",
                ),
            ],
            unmappedFindings: [],
            rejectedFieldIds: [],
        )

        let result = DNeuralUltrasoundDictationProposalReconciler.reconcile(
            request: request,
            labeled: labeled,
            explicit: [],
            generated: generated,
        )

        #expect(
            result.proposals.first { $0.id == .examinationNumber }?.value == .text(
                "007",
            ),
        )
        #expect(
            result.proposals.first { $0.id == .examinationNumber }?.warnings.contains(
                .ambiguousDictation,
            ) == true,
        )
        #expect(
            result.proposals.first { $0.id == .examinationDescription }?.value == .text(
                "left kidney: 35 mm. No abnormality.",
            ),
        )
        #expect(
            result.rejectedFieldIds.isEmpty,
        )
        switch result.fieldSources[
            .examinationDescription,
        ] {
        case .localModel: break
        case .labeledDictation, .explicitFacts, .serverModel, .none: Issue.record(
                "Wrong description source",
            )
        }
    }

    @Test(
        "Capitalization alone does not create a conflict on a clinical complaint",
    )
    func sameComplaintWithDifferentCase() {
        let request = DNeuralUltrasoundDictationParseRequest(
            text: "The patient reports tenderness.",
            examinationTypeId: "echocardiography",
            examinationTypeTitle: "Unit-test examination",
            locale: Locale(
                identifier: "en_US",
            ),
            allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
            localization: VoiceLocalizationTestSupport.dictation(
                locale: Locale(
                    identifier: "en_US",
                ),
            ),
        )
        let explicit = [DNeuralUltrasoundVoiceFieldProposal(
            id: .patientComplaints,
            value: .text(
                "tenderness",
            ),
            sourceQuote: "The patient reports tenderness.",
        )]
        let generated = DNeuralUltrasoundDictationProposal(
            source: .localModel,
            proposals: [DNeuralUltrasoundVoiceFieldProposal(
                id: .patientComplaints,
                value: .text(
                    "Tenderness",
                ),
                sourceQuote: "The patient reports tenderness.",
            )],
            unmappedFindings: [],
            rejectedFieldIds: [],
        )
        let result = DNeuralUltrasoundDictationProposalReconciler.reconcile(
            request: request,
            labeled: nil,
            explicit: explicit,
            generated: generated,
        )
        #expect(
            result.proposals[
                0,
            ].value == .text(
                "tenderness",
            ),
        )
        #expect(
            result.proposals[
                0,
            ].warnings.isEmpty,
        )
    }

    @Test(
        "Natural Language keeps ambiguity found by the shared reconciler",
    )
    func naturalLanguagePreservesAmbiguity() {
        let request = DNeuralUltrasoundDictationParseRequest(
            text: "Описание исследования: подключичная вена: одиннадцать миллиметров. Жалобы: возможно отёчность. "
                + "Номер исследования: ноль четыре восемь. Пациент: Наталья Белова.",
            examinationTypeId: "veinsOfTheUpperExtremities",
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
        let rules = DNeuralUltrasoundDictationProposalReconciler.reconcile(
            request: request,
            labeled: DNeuralUltrasoundDictationLabeledFormParser.parse(
                request: request,
            ),
            explicit: DNeuralUltrasoundDictationExplicitFactsExtractor.extract(
                request: request,
            ),
            generated: nil,
        )
        let naturalLanguage = DNeuralUltrasoundDictationNaturalLanguageParser.parse(
            request: request,
        )
        let rulesComplaints = rules.proposals.first { $0.id == .patientComplaints }
        let naturalLanguageComplaints = naturalLanguage.proposals.first { $0.id == .patientComplaints }

        #expect(
            rulesComplaints?.warnings.contains(
                .ambiguousDictation,
            ) == true,
        )
        #expect(
            naturalLanguageComplaints?.warnings == rulesComplaints?.warnings,
        )
        #expect(
            naturalLanguageComplaints?.accuracy == .questionable,
        )
    }
}

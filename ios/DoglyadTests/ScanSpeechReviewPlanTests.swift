@testable import Doglyad
import DoglyadNeuralModel
import Testing

struct ScanSpeechReviewPlanTests {
    private let weight = DNeuralUltrasoundVoiceFieldProposal(
        id: .patientWeightKG,
        value: .number(
            70,
        ),
        sourceQuote: "Weight 70 kg",
    )
    private let height = DNeuralUltrasoundVoiceFieldProposal(
        id: .patientHeightCM,
        value: .number(
            175,
        ),
        sourceQuote: "Height 175 cm",
    )

    @Test
    func automaticFieldsWithoutRemainingIssuesCompleteTheFlow() {
        let plan = makePlan(
            automatic: [weight],
        )
        #expect(
            plan.decision == .complete,
        )
    }

    @Test
    func emptyResultReturnsToTranscriptReview() {
        let plan = makePlan()
        #expect(
            plan.decision == .reviewTranscript,
        )
    }

    @Test(
        arguments: [false, true],
    )
    func uncertainFieldsRequireReview(
        isAutomaticIncluded: Bool,
    ) {
        let plan = makePlan(
            automatic: isAutomaticIncluded ? [weight] : [],
            uncertain: [height],
        )
        #expect(
            plan.decision == .reviewProposals,
        )
    }

    @Test(
        arguments: [false, true],
    )
    func rejectedFieldsRequireReview(
        isAutomaticIncluded: Bool,
    ) {
        let plan = makePlan(
            automatic: isAutomaticIncluded ? [weight] : [],
            rejectedFieldIds: [.patientDateOfBirth],
        )
        #expect(
            plan.decision == .reviewProposals,
        )
    }

    @Test(
        arguments: [false, true],
    )
    func unmappedFindingsRequireReview(
        isAutomaticIncluded: Bool,
    ) {
        let plan = makePlan(
            automatic: isAutomaticIncluded ? [weight] : [],
            unmappedFindings: ["Additional dictated finding"],
        )
        #expect(
            plan.decision == .reviewProposals,
        )
    }

    private func makePlan(
        automatic: [DNeuralUltrasoundVoiceFieldProposal] = [],
        uncertain: [DNeuralUltrasoundVoiceFieldProposal] = [],
        rejectedFieldIds: [DNeuralUltrasoundVoiceFieldId] = [],
        unmappedFindings: [String] = [],
    ) -> ScanSpeechReviewPlan {
        ScanSpeechReviewPlan(
            proposal: DNeuralUltrasoundDictationProposal(
                source: .serverModel,
                proposals: automatic + uncertain,
                unmappedFindings: unmappedFindings,
                rejectedFieldIds: rejectedFieldIds,
            ),
            automatic: automatic,
            uncertain: uncertain,
        )
    }
}

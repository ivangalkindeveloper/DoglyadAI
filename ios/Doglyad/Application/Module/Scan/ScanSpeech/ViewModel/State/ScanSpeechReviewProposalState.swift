import DoglyadNeuralModel

@MainActor
final class ScanSpeechReviewProposalState: ScanSpeechStateProtocol, @MainActor Equatable {
    let proposal: DNeuralUltrasoundDictationProposal
    let reviewProposals: [DNeuralUltrasoundVoiceFieldProposal]
    let selectedFieldIds: Set<DNeuralUltrasoundVoiceFieldId>

    init(
        proposal: DNeuralUltrasoundDictationProposal,
        reviewProposals: [DNeuralUltrasoundVoiceFieldProposal],
        selectedFieldIds: Set<DNeuralUltrasoundVoiceFieldId> = [],
    ) {
        self.proposal = proposal
        self.reviewProposals = reviewProposals
        self.selectedFieldIds = selectedFieldIds
    }

    static func == (
        lhs: ScanSpeechReviewProposalState,
        rhs: ScanSpeechReviewProposalState,
    ) -> Bool {
        lhs.proposal == rhs.proposal
            && lhs.reviewProposals == rhs.reviewProposals
            && lhs.selectedFieldIds == rhs.selectedFieldIds
    }
}

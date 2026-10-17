import DoglyadNeuralModel

@MainActor
final class ScanSpeechProposalReviewState: ScanSpeechStateProtocol {
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
}

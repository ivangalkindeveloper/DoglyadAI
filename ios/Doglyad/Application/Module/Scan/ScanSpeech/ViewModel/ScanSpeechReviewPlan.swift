import DoglyadNeuralModel

struct ScanSpeechReviewPlan {
    let proposal: DNeuralUltrasoundDictationProposal
    let automatic: [DNeuralUltrasoundVoiceFieldProposal]
    let uncertain: [DNeuralUltrasoundVoiceFieldProposal]

    init(
        proposal: DNeuralUltrasoundDictationProposal,
        automatic: [DNeuralUltrasoundVoiceFieldProposal],
        uncertain: [DNeuralUltrasoundVoiceFieldProposal],
    ) {
        self.proposal = proposal
        self.automatic = automatic
        self.uncertain = uncertain
    }

    var decision: ScanSpeechReviewDecision {
        if uncertain.isEmpty, !automatic.isEmpty {
            return .complete
        }
        if proposal.proposals.isEmpty {
            return .reviewTranscript
        }
        return .reviewProposals
    }
}

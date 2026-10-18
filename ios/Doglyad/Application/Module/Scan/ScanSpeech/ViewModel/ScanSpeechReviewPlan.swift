import DoglyadNeuralModel

struct ScanSpeechReviewPlan {
    let proposal: DNeuralUltrasoundDictationProposal
    let automatic: [DNeuralUltrasoundVoiceFieldProposal]
    let uncertain: [DNeuralUltrasoundVoiceFieldProposal]

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

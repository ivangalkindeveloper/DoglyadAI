import DoglyadNeuralModel

struct ScanSpeechReviewPlan {
    let proposal: DNeuralUltrasoundDictationProposal
    let automatic: [DNeuralUltrasoundVoiceFieldProposal]
    let uncertain: [DNeuralUltrasoundVoiceFieldProposal]

    var decision: ScanSpeechReviewDecision {
        if uncertain.isEmpty, proposal.rejectedFieldIds.isEmpty, proposal.unmappedFindings.isEmpty, !automatic.isEmpty {
            return .complete
        }
        if proposal.proposals.isEmpty, proposal.rejectedFieldIds.isEmpty, proposal.unmappedFindings.isEmpty {
            return .reviewTranscript
        }
        return .reviewProposals
    }
}

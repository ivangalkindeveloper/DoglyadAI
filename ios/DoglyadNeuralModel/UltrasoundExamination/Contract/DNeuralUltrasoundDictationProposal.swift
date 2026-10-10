import Foundation

public struct DNeuralUltrasoundDictationProposal: Sendable {
    public let source: DNeuralDictationProposalSource
    public let proposals: [DNeuralUltrasoundVoiceFieldProposal]
    public let unmappedFindings: [String]
    public let rejectedFieldIds: [DNeuralUltrasoundVoiceFieldId]
    public let fieldSources: [DNeuralUltrasoundVoiceFieldId: DNeuralDictationProposalSource]

    public init(
        source: DNeuralDictationProposalSource,
        proposals: [DNeuralUltrasoundVoiceFieldProposal],
        unmappedFindings: [String],
        rejectedFieldIds: [DNeuralUltrasoundVoiceFieldId],
        fieldSources: [DNeuralUltrasoundVoiceFieldId: DNeuralDictationProposalSource] = [:],
    ) {
        self.source = source
        self.proposals = proposals
        self.unmappedFindings = unmappedFindings
        self.rejectedFieldIds = rejectedFieldIds
        self.fieldSources = fieldSources
    }
}

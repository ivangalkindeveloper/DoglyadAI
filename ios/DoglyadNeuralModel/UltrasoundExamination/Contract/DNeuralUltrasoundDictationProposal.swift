import Foundation

public struct DNeuralUltrasoundDictationProposal: Equatable, Sendable {
    public let source: DNeuralDictationProposalSource
    public let proposals: [DNeuralUltrasoundVoiceFieldProposal]
    public let fieldSources: [DNeuralUltrasoundVoiceFieldId: DNeuralDictationProposalSource]

    public init(
        source: DNeuralDictationProposalSource,
        proposals: [DNeuralUltrasoundVoiceFieldProposal],
        fieldSources: [DNeuralUltrasoundVoiceFieldId: DNeuralDictationProposalSource] = [:],
    ) {
        self.source = source
        self.proposals = proposals
        self.fieldSources = fieldSources
    }
}

public struct DNeuralUltrasoundVoiceFieldProposal: Identifiable, Equatable, Sendable {
    public let id: DNeuralUltrasoundVoiceFieldId
    public let value: DNeuralVoiceFieldValue
    public let sourceQuote: String
    public let accuracy: DNeuralVoiceFieldAccuracy
    public let warnings: [DNeuralVoiceProposalWarning]

    public init(
        id: DNeuralUltrasoundVoiceFieldId,
        value: DNeuralVoiceFieldValue,
        sourceQuote: String,
        accuracy: DNeuralVoiceFieldAccuracy = .full,
        warnings: [DNeuralVoiceProposalWarning] = [],
    ) {
        self.id = id
        self.value = value
        self.sourceQuote = sourceQuote
        self.accuracy = warnings.isEmpty ? accuracy : .questionable
        self.warnings = warnings
    }
}

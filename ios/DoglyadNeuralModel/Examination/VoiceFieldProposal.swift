public struct VoiceFieldProposal: Identifiable, Equatable, Sendable {
    public let id: VoiceFieldId
    public let value: VoiceFieldValue
    public let sourceQuote: String
    public let accuracy: VoiceFieldAccuracy
    public let warnings: [VoiceProposalWarning]

    public init(
        id: VoiceFieldId, value: VoiceFieldValue, sourceQuote: String,
        accuracy: VoiceFieldAccuracy = .full, warnings: [VoiceProposalWarning] = []
    ) {
        self.id = id
        self.value = value
        self.sourceQuote = sourceQuote
        self.accuracy = warnings.isEmpty ? accuracy : .questionable
        self.warnings = warnings
    }
}

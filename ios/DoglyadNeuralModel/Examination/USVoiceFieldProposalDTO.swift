public struct USVoiceFieldProposalDTO: Decodable, Sendable {
    public let fieldId: VoiceFieldId
    public let value: String
    public let sourceQuote: String
}

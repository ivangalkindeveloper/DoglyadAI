public struct USVoiceFormParseResponseDTO: Decodable, Sendable {
    public let proposals: [USVoiceFieldProposalDTO]
    public let rejectedFieldIds: [VoiceFieldId]
    public let unmappedFindings: [String]
}

public struct USVoiceFormParseResponseDTO: Decodable, Sendable {
    public let proposals: [USVoiceFieldProposalDTO]
    public let rejectedFieldIds: [VoiceFieldId]
    public let unmappedFindings: [String]

    private enum CodingKeys: String, CodingKey {
        case proposals
        case rejectedFieldIds
        case unmappedFindings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        proposals = try container.decode([USVoiceFieldProposalDTO].self, forKey: .proposals)
        let rejected = try container.decode([String].self, forKey: .rejectedFieldIds)
        rejectedFieldIds = try rejected.map { wireId in
            guard let field = VoiceFieldId(wireValue: wireId) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .rejectedFieldIds, in: container, debugDescription: "Unknown field ID"
                )
            }
            return field
        }
        unmappedFindings = try container.decode([String].self, forKey: .unmappedFindings)
    }
}

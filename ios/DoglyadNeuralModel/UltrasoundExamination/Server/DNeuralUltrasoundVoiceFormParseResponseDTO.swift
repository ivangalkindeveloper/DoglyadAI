public struct DNeuralUltrasoundVoiceFormParseResponseDTO: Decodable, Sendable {
    public let proposals: [DNeuralUltrasoundVoiceFieldProposalDTO]
    public let rejectedFieldIds: [DNeuralUltrasoundVoiceFieldId]
    public let unmappedFindings: [String]

    private enum DNeuralUltrasoundCodingKeys: String, CodingKey {
        case proposals
        case rejectedFieldIds
        case unmappedFindings
    }

    public init(
        from decoder: Decoder,
    ) throws {
        let container = try decoder.container(
            keyedBy: DNeuralUltrasoundCodingKeys.self,
        )
        proposals = try container.decode(
            [DNeuralUltrasoundVoiceFieldProposalDTO].self,
            forKey: .proposals,
        )
        let rejected = try container.decode(
            [String].self,
            forKey: .rejectedFieldIds,
        )
        rejectedFieldIds = try rejected.map { wireId in
            guard let field = DNeuralUltrasoundVoiceFieldId(
                wireValue: wireId,
            ) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .rejectedFieldIds,
                    in: container,
                    debugDescription: "Unknown field ID",
                )
            }
            return field
        }
        unmappedFindings = try container.decode(
            [String].self,
            forKey: .unmappedFindings,
        )
    }
}

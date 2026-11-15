public struct DNeuralUltrasoundVoiceFormParseResponseDTO: Decodable, Sendable {
    public let proposals: [DNeuralUltrasoundVoiceFieldProposalDTO]

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
    }

    private enum DNeuralUltrasoundCodingKeys: String, CodingKey {
        case proposals
    }
}

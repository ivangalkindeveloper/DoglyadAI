public struct DNeuralUltrasoundVoiceFormParseResponseDTO: Decodable, Sendable {
    public let proposals: [DNeuralUltrasoundVoiceFieldProposalDTO]

    private enum DNeuralUltrasoundCodingKeys: String, CodingKey {
        case proposals
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
    }
}

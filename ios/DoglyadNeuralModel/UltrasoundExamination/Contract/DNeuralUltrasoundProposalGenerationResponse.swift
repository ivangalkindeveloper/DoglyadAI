

struct DNeuralUltrasoundProposalGenerationResponse: Codable, Sendable {
    let proposals: [DNeuralUltrasoundProposalGenerationItem]
}

extension DNeuralUltrasoundProposalGenerationResponse {
    init(
        serverResponse: DNeuralUltrasoundVoiceFormParseResponseDTO,
    ) {
        self.init(
            proposals: serverResponse.proposals.map {
                DNeuralUltrasoundProposalGenerationItem(
                    fieldId: $0.fieldId,
                    value: $0.value,
                    sourceQuote: $0.sourceQuote,
                    accuracy: $0.accuracy,
                )
            },
        )
    }

    @available(iOS 26.0, *)
    static func fromFoundationModels(
        _ response: [DNeuralUltrasoundFoundationProposalItem],
    ) -> Self {
        var proposals: [DNeuralUltrasoundProposalGenerationItem] = []
        for item in response {
            guard let fieldId = DNeuralUltrasoundVoiceFieldId(
                wireValue: item.field_id,
            ) else {
                continue
            }
            proposals.append(
                DNeuralUltrasoundProposalGenerationItem(
                    fieldId: fieldId,
                    value: item.value,
                    sourceQuote: item.evidence,
                    accuracy: DNeuralVoiceFieldAccuracy(
                        rawValue: item.accuracy,
                    ) ?? .questionable,
                ),
            )
        }
        return Self(
            proposals: proposals,
        )
    }
}

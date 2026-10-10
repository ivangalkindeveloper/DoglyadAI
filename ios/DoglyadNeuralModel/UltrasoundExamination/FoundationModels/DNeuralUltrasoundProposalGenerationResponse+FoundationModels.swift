extension DNeuralUltrasoundProposalGenerationResponse {
    @available(iOS 26.0, *)
    static func fromFoundationModels(
        _ response: [DNeuralUltrasoundFoundationProposalItem],
    ) -> Self {
        var proposals: [DNeuralUltrasoundProposalGenerationItem] = []
        var unmappedFindings: [String] = []
        for item in response {
            guard let fieldId = DNeuralUltrasoundVoiceFieldId(
                wireValue: item.field_id,
            ) else {
                unmappedFindings.append(
                    item.evidence,
                )
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
            unmappedFindings: unmappedFindings,
        )
    }
}

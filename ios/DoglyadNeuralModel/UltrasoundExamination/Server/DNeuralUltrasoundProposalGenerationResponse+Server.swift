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
            unmappedFindings: serverResponse.unmappedFindings,
        )
    }
}

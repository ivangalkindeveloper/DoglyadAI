/// Native generation boundary, also used by test recorders and model substitutes.
protocol DNeuralUltrasoundProposalGeneratorProtocol: DNeuralModelProtocol {
    func generateProposals(
        request: DNeuralUltrasoundDictationParseRequest,
    ) async throws -> DNeuralUltrasoundProposalGenerationResponse
}

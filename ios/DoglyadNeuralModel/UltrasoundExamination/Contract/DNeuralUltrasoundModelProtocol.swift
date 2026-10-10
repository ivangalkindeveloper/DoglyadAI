public protocol DNeuralUltrasoundModelProtocol: DNeuralModelProtocol {
    func parseProposals(
        request: DNeuralUltrasoundDictationParseRequest,
    ) async throws -> DNeuralUltrasoundDictationProposal
}

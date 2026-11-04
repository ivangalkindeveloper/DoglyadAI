import Foundation

public final class DNeuralUltrasoundModelServer: DNeuralUltrasoundModelProtocol {
    private let parseDictation: (String?, String, String) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO

    public init(
        parseDictation: @escaping (String?, String, String) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO,
    ) {
        self.parseDictation = parseDictation
    }

    /// The remote engine is managed by the backend; preparing it sends no request.
    public func prewarm() {}

    public func parseProposals(
        request: DNeuralUltrasoundDictationParseRequest,
    ) async throws -> DNeuralUltrasoundDictationProposal {
        try Task.checkCancellation()
        let response = try await parseDictation(
            request.selectedNeuralModelId,
            request.examinationTypeId,
            request.text,
        )
        try Task.checkCancellation()
        return try DNeuralUltrasoundProposalProcessor(
            request: request,
        ).process(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                serverResponse: response,
            ),
            source: .serverModel,
        )
    }
}

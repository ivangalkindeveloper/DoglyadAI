import Foundation

public final class DNeuralUltrasoundModelServer: DNeuralUltrasoundModelProtocol {
    private let parseTranscript: (String, String, String) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO

    public init(
        parseTranscript: @escaping (String, String, String) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO,
    ) {
        self.parseTranscript = parseTranscript
    }

    /// The remote engine is managed by the backend; preparing it sends no request.
    public func prewarm() {}

    public func parseProposals(
        request: DNeuralUltrasoundDictationParseRequest,
    ) async throws -> DNeuralUltrasoundDictationProposal {
        try Task.checkCancellation()
        guard let selectedNeuralModelId = request.selectedNeuralModelId else {
            throw DNeuralModelError.unavailable
        }
        let response = try await parseTranscript(
            selectedNeuralModelId,
            request.examinationTypeId,
            request.text,
        )
        try Task.checkCancellation()
        return try Self.process(
            response: response,
            request: request,
        )
    }

    /// Validates an already generated response without another model request.
    public static func process(
        response: DNeuralUltrasoundVoiceFormParseResponseDTO,
        request: DNeuralUltrasoundDictationParseRequest,
    ) throws -> DNeuralUltrasoundDictationProposal {
        try DNeuralUltrasoundProposalProcessor(
            request: request,
        ).process(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                serverResponse: response,
            ),
            source: .serverModel,
        )
    }
}

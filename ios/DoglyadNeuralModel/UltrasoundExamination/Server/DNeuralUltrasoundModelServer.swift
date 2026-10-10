import Foundation

public final class DNeuralUltrasoundModelServer: DNeuralUltrasoundModelProtocol {
    private let transport: any DNeuralUltrasoundServerTransportProtocol

    public init(
        transport: any DNeuralUltrasoundServerTransportProtocol,
    ) {
        self.transport = transport
    }

    /// The remote engine is managed by the backend; preparing it sends no request.
    public func prewarm() {}

    public func parseProposals(
        request: DNeuralUltrasoundDictationParseRequest,
    ) async throws -> DNeuralUltrasoundDictationProposal {
        try Task.checkCancellation()
        let response = try await transport.parseDictation(
            locale: request.locale,
            examinationTypeId: request.examinationTypeId,
            transcript: request.text,
        )
        try Task.checkCancellation()
        return try DNeuralUltrasoundProposalProcessor(
            request: request,
        ).process(
            generated: DNeuralUltrasoundProposalGenerationResponse(
                serverResponse: response,
            ),
            source: .serverModel,
            rejectedFieldIds: response.rejectedFieldIds,
        )
    }
}

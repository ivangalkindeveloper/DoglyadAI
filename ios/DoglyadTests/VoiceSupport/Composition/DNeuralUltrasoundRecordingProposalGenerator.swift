@testable import DoglyadNeuralModel

/// Records the one real generation used by the production model, without replaying it.
final class DNeuralUltrasoundRecordingProposalGenerator: DNeuralUltrasoundProposalGeneratorProtocol {
    private let base: any DNeuralUltrasoundProposalGeneratorProtocol
    private(set) var calls = 0
    private(set) var generated: DNeuralUltrasoundProposalGenerationResponse?
    private(set) var error: (any Error)?

    init(
        base: any DNeuralUltrasoundProposalGeneratorProtocol,
    ) { self.base = base }

    func prewarm() { base.prewarm() }

    func generateProposals(
        request: DNeuralUltrasoundDictationParseRequest,
    ) async throws -> DNeuralUltrasoundProposalGenerationResponse {
        calls += 1
        do {
            let response = try await base.generateProposals(
                request: request,
            )
            generated = response
            return response
        } catch {
            self.error = error
            throw error
        }
    }
}

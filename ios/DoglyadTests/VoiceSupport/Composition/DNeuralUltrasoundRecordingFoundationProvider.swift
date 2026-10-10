@testable import DoglyadNeuralModel

@MainActor
final class DNeuralUltrasoundRecordingFoundationProvider: DNeuralUltrasoundFoundationModelProviderProtocol {
    private let base: DNeuralUltrasoundFoundationModelProvider
    private(set) var recorder: DNeuralUltrasoundRecordingProposalGenerator?

    init(
        base: DNeuralUltrasoundFoundationModelProvider,
    ) { self.base = base }

    var isAvailable: Bool { base.isAvailable }

    func makeModel() throws -> any DNeuralUltrasoundModelProtocol {
        guard #available(iOS 26.0, *) else { throw DNeuralModelError.unavailable }
        let recorder = DNeuralUltrasoundRecordingProposalGenerator(
            base: DNeuralUltrasoundFoundationProposalGenerator(
                proposalPrompt: base.proposalPrompt,
                parameters: base.parameters,
            ),
        )
        self.recorder = recorder
        return DNeuralUltrasoundModelFoundationModels(
            generator: recorder,
        )
    }
}

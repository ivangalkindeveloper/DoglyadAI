import Foundation
import FoundationModels

public final class DNeuralUltrasoundModelFoundationModels: DNeuralUltrasoundModelProtocol {
    public static func isAvailable(
        locale: Locale,
    ) -> Bool {
        guard #available(iOS 26.0, *) else { return false }
        let model = SystemLanguageModel.default
        return model.isAvailable && model.supportsLocale(
            locale,
        )
    }

    private let generator: any DNeuralUltrasoundProposalGeneratorProtocol

    @available(iOS 26.0, *)
    public convenience init(
        proposalPrompt: String,
        parameters: DNeuralGenerationParameters,
    ) {
        self.init(
            generator: DNeuralUltrasoundFoundationProposalGenerator(
                proposalPrompt: proposalPrompt,
                parameters: parameters,
            ),
        )
    }

    init(
        generator: any DNeuralUltrasoundProposalGeneratorProtocol,
    ) {
        self.generator = generator
    }

    public func prewarm() {
        generator.prewarm()
    }

    public func parseProposals(
        request: DNeuralUltrasoundDictationParseRequest,
    ) async throws -> DNeuralUltrasoundDictationProposal {
        try Task.checkCancellation()
        let processor = DNeuralUltrasoundProposalProcessor(
            request: request,
        )
        do {
            let generated = try await generator.generateProposals(
                request: request,
            )
            try Task.checkCancellation()
            return try processor.process(
                generated: generated,
                source: .localModel,
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            let deterministic = processor.deterministic
            guard !deterministic.proposals.isEmpty else { throw error }
            return deterministic
        }
    }
}

import Foundation
import FoundationModels

/// Owns Apple sessions and the conversion from the native schema to model output.
@available(iOS 26.0, *)
final class DNeuralUltrasoundFoundationProposalGenerator: DNeuralUltrasoundProposalGeneratorProtocol {
    private let proposalPrompt: String
    private let generationOptions: GenerationOptions
    private var prewarmedSession: LanguageModelSession?
    private let lock = NSLock()

    init(
        proposalPrompt: String,
        parameters: DNeuralGenerationParameters,
    ) {
        self.proposalPrompt = proposalPrompt
        generationOptions = GenerationOptions(
            temperature: parameters.temperature,
            maximumResponseTokens: parameters.maxTokens,
        )
    }

    func prewarm() {
        lock.lock()
        defer { lock.unlock() }
        guard prewarmedSession == nil else { return }
        let session = LanguageModelSession(
            instructions: proposalPrompt,
        )
        session.prewarm()
        prewarmedSession = session
    }

    private func takeSession() -> LanguageModelSession {
        lock.lock()
        defer { lock.unlock() }
        // A separate session per dictation prevents previous patient data entering the next request.
        let session = prewarmedSession ?? LanguageModelSession(
            instructions: proposalPrompt,
        )
        prewarmedSession = nil
        return session
    }

    func generateProposals(
        request: DNeuralUltrasoundDictationParseRequest,
    ) async throws -> DNeuralUltrasoundProposalGenerationResponse {
        guard !proposalPrompt.trimmingCharacters(
            in: .whitespacesAndNewlines,
        ).isEmpty else {
            throw DNeuralModelError.proposalPromptUnavailable
        }
        let session = takeSession()
        let response = try await session.respond(
            to: DNeuralUltrasoundProposalGenerationConfig.userPrompt(
                for: request,
            ),
            schema: DNeuralUltrasoundFoundationProposalItem.arraySchema(
                localization: request.localization.schema,
            ),
            options: generationOptions,
        )
        return try DNeuralUltrasoundProposalGenerationResponse.fromFoundationModels(
            [DNeuralUltrasoundFoundationProposalItem](
                response.content,
            ),
        )
    }
}

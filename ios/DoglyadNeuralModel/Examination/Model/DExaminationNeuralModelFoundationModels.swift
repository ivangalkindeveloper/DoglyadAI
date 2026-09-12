import Foundation
import FoundationModels

@available(iOS 26.0, *)
public final class DExaminationNeuralModelFoundationModels: DExaminationNeuralModelProtocol {
    @FoundationModels.Generable
    struct Response {
        @FoundationModels.Guide(description: "Patient name, number, or nickname")
        let patientName: String?

        @FoundationModels.Guide(description: "Patient gender")
        let patientGender: Gender?

        @FoundationModels.Guide(description: "Patient date of birth in the following format \(DExaminationGenerationConfig.promptDateFormat)")
        let patientDateOfBirth: String?

        @FoundationModels.Guide(description: "Patient height in centimeters")
        let patientHeightCM: Double?

        @FoundationModels.Guide(description: "Patient weight in kilograms")
        let patientWeightKG: Double?

        @FoundationModels.Guide(description: "Patient complaints")
        let patientComplaint: String?

        @FoundationModels.Guide(description: "Examination description, including any technical details such as device model, probe types, and the number of saved photographs and videos")
        let examinationDescription: String?
    }

    @FoundationModels.Generable
    enum Gender {
        case male
        case female
    }

    public static func isAvailable(
        locale: Locale,
        parameters _: DExaminationGenerationParameters
    ) -> Bool {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return false }

        // The system model does not cover every app language, yet it stays
        // "available" on the uncovered ones too. Without this check we would prefer
        // it over MLX on a locale whose language it does not know. The language set
        // changes between system releases, so we ask at runtime instead of hardcoding.
        guard let languageCode = locale.language.languageCode else { return false }

        return model.supportedLanguages.contains { $0.languageCode == languageCode }
    }

    private let systemPrompt: String
    private let generationOptions: GenerationOptions
    /// A session warmed up for the next parse. It is created ahead of time: on the
    /// first request the model compiles the response schema and raises guardrails, and
    /// without warm-up that delay lands on the physician right after dictating.
    private var prewarmedSession: LanguageModelSession?
    /// `parseSpeech` and `prewarm` are called from different contexts and the session
    /// has to be swapped, so access to it is guarded by a lock.
    private let lock = NSLock()

    public init(
        systemPrompt: String,
        parameters: DExaminationGenerationParameters
    ) {
        self.systemPrompt = systemPrompt
        generationOptions = GenerationOptions(
            temperature: parameters.temperature,
            maximumResponseTokens: parameters.maxTokens
        )
    }

    public func prewarm() {
        lock.lock()
        defer { lock.unlock() }

        guard prewarmedSession == nil else { return }

        let session = LanguageModelSession(instructions: systemPrompt)
        session.prewarm()
        prewarmedSession = session
    }

    /// Takes the warmed-up session for the current parse. Synchronous — the lock
    /// must not be held across `await`.
    ///
    /// Each dictation is parsed independently while a session accumulates a transcript,
    /// so the warmed one is taken whole and the next `prewarm` creates a new one.
    private func takeSession() -> LanguageModelSession {
        lock.lock()
        defer { lock.unlock() }

        let session = prewarmedSession ?? LanguageModelSession(instructions: systemPrompt)
        prewarmedSession = nil

        return session
    }

    public func parseSpeech(
        speech: String
    ) async throws -> DExaminationNeuralModelResponse {
        let session = takeSession()
        let response = try await session.respond(
            to: DExaminationGenerationConfig.userPrompt(for: speech),
            generating: Response.self,
            options: generationOptions
        )

        return DExaminationNeuralModelResponse.fromFoudationModels(
            response.content
        )
    }
}

import Foundation

public enum DExaminationNeuralModelError: Error {
    case unavailable
    case resourceNotFound
}

public protocol DExaminationNeuralModelProtocol {
    /// Availability of the implementation. The locale matters as much as the system:
    /// the model may be installed yet not know the dictation language, and then it
    /// cannot be used for parsing.
    static func isAvailable(
        locale: Locale,
        parameters: DExaminationGenerationParameters
    ) -> Bool

    init(
        systemPrompt: String,
        parameters: DExaminationGenerationParameters
    ) async throws

    /// Warms the model up so the first parse does not pay for initialization.
    /// Called when the physician starts dictating: there is time while they speak.
    func prewarm()

    func parseSpeech(
        speech: String
    ) async throws -> DExaminationNeuralModelResponse
}

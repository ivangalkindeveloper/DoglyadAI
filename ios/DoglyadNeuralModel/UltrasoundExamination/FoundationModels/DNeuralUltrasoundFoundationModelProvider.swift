import Foundation

@MainActor
struct DNeuralUltrasoundFoundationModelProvider: DNeuralUltrasoundFoundationModelProviderProtocol {
    let locale: Locale
    let proposalPrompt: String
    let parameters: DNeuralGenerationParameters

    var isAvailable: Bool {
        !proposalPrompt.trimmingCharacters(
            in: .whitespacesAndNewlines,
        ).isEmpty
            && DNeuralUltrasoundModelFoundationModels.isAvailable(
                locale: locale,
            )
    }

    func makeModel() throws -> any DNeuralUltrasoundModelProtocol {
        guard #available(iOS 26.0, *) else { throw DNeuralModelError.unavailable }
        return DNeuralUltrasoundModelFoundationModels(
            proposalPrompt: proposalPrompt,
            parameters: parameters,
        )
    }
}

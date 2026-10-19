import Foundation

/// Implemented by the application with its existing DoglyadNetwork client.
public protocol DNeuralUltrasoundServerTransportProtocol {
    func parseDictation(
        selectedNeuralModelId: String?,
        locale: Locale,
        examinationTypeId: String,
        transcript: String,
    ) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO
}

import DoglyadNeuralModel
import Foundation

/// The local-only candidate benchmark does not bootstrap App Check or make server calls.
struct DNeuralUltrasoundUnavailableTestTransport: DNeuralUltrasoundServerTransportProtocol {
    func parseDictation(
        locale _: Locale,
        examinationTypeId _: String,
        transcript _: String,
    ) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO {
        throw DNeuralModelError.unavailable
    }
}

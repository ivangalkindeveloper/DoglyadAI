import DoglyadNeuralModel
import Foundation

/// The device benchmark retries requests; the production transport keeps its existing policy.
final class DNeuralUltrasoundRetryingTestTransport {
    private let base: (String?, String, String) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO
    private let isFoundationOnly: Bool
    private(set) var calls = 0

    init(
        base: @escaping (String?, String, String) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO,
        isFoundationOnly: Bool,
    ) {
        self.base = base
        self.isFoundationOnly = isFoundationOnly
    }

    func parseDictation(
        selectedNeuralModelId: String?,
        examinationTypeId: String,
        transcript: String,
    ) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO {
        guard !isFoundationOnly else {
            throw DNeuralModelError.unavailable
        }
        for attempt in 1 ... 3 {
            try Task.checkCancellation()
            calls += 1
            do {
                return try await base(
                    selectedNeuralModelId,
                    examinationTypeId,
                    transcript,
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if attempt == 3 {
                    throw error
                }
                try await Task.sleep(
                    for: .seconds(
                        2,
                    ),
                )
            }
        }
        throw DNeuralModelError.unavailable
    }
}

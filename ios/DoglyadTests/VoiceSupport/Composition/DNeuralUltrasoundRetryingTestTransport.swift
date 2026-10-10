import DoglyadNeuralModel
import Foundation

/// The device benchmark retries requests; the production transport keeps its existing policy.
final class DNeuralUltrasoundRetryingTestTransport: DNeuralUltrasoundServerTransportProtocol {
    private let base: any DNeuralUltrasoundServerTransportProtocol
    private let foundationOnly: Bool
    private(set) var calls = 0

    init(
        base: any DNeuralUltrasoundServerTransportProtocol,
        foundationOnly: Bool,
    ) {
        self.base = base
        self.foundationOnly = foundationOnly
    }

    func parseDictation(
        locale: Locale,
        examinationTypeId: String,
        transcript: String,
    ) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO {
        guard !foundationOnly else { throw DNeuralModelError.unavailable }
        for attempt in 1 ... 3 {
            try Task.checkCancellation()
            calls += 1
            do {
                return try await base.parseDictation(
                    locale: locale,
                    examinationTypeId: examinationTypeId,
                    transcript: transcript,
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if attempt == 3 { throw error }
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

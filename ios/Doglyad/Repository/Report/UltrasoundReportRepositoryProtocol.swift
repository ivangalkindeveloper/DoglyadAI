import DoglyadNetwork
import DoglyadNeuralModel
import Foundation

protocol UltrasoundReportRepositoryProtocol: AnyObject {
    func prepareGeneration(
        request: USReportGenerationRequest,
        photoOptions: ScanPhotoEncodingOptions,
    ) async throws -> Data

    func startGeneration(
        data: Data,
    ) async throws -> USReportGenerationResponse

    func generation(
        id: UUID,
    ) async throws -> USReportGenerationResponse

    func generationEvents(
        id: UUID,
    ) async throws -> AsyncThrowingStream<DServerEvent, Error>

    func cancelGeneration(
        id: UUID,
    ) async throws -> USReportGenerationResponse

    func getSelectedExaminationTypeId() async throws -> String?

    func setSelectedExaminationTypeId(
        id: String,
    ) async throws

    func getRecentExaminationTypeIds() async throws -> [String]

    func setRecentExaminationTypeIds(
        _ ids: [String],
    ) async throws

    func recordRecentExaminationTypeId(
        _ id: String,
    ) async throws

    func getReports(
        limit: Int,
        offset: Int,
    ) async throws -> [USExaminationReport]

    func interruptPendingGenerations() async throws

    func getReportsCount() async throws -> Int

    func setReport(
        report: USExaminationReport,
    ) async throws

    func updateGeneratedReport(
        report: USExaminationReport,
    ) async throws

    func updateReport(
        report: USExaminationReport,
    ) async throws

    func clearAllReports() async throws

    @MainActor func clearAll() async throws

    func parseDictation(
        selectedNeuralModelId: String?,
        examinationTypeId: String,
        transcript: String,
    ) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO
}

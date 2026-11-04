import DoglyadDatabase
import DoglyadNetwork
import DoglyadNeuralModel
import Foundation

final class UltrasoundReportRepository: UltrasoundReportRepositoryProtocol {
    let database: DDatabaseProtocol
    let httpClient: DHttpClientProtocol

    init(
        database: DDatabaseProtocol,
        httpClient: DHttpClientProtocol,
    ) {
        self.database = database
        self.httpClient = httpClient
    }

    func prepareGeneration(
        request: USReportGenerationRequest,
        photoOptions: ScanPhotoEncodingOptions,
    ) async throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.userInfo[
            .scanPhotoEncodingOptions,
        ] = photoOptions
        return try encoder.encode(
            request,
        )
    }

    func startGeneration(
        data: Data,
    ) async throws -> USReportGenerationResponse {
        try await httpClient.post(
            endPoint: "/ultrasound/report_generations",
            data: data,
        )
    }

    func generation(
        id: UUID,
    ) async throws -> USReportGenerationResponse {
        try await httpClient.get(
            endPoint: "/ultrasound/report_generations/\(id.uuidString)",
        )
    }

    func generationEvents(
        id: UUID,
    ) async throws -> AsyncThrowingStream<DServerEvent, Error> {
        try await httpClient.serverEvents(
            endPoint: "/ultrasound/report_generations/\(id.uuidString)/events",
        )
    }

    func cancelGeneration(
        id: UUID,
    ) async throws -> USReportGenerationResponse {
        try await httpClient.post(
            endPoint: "/ultrasound/report_generations/\(id.uuidString)/cancel",
        )
    }

    func getSelectedExaminationTypeId() async throws -> String? {
        database.getSelectedUSExaminationTypeId()
    }

    func setSelectedExaminationTypeId(
        id: String,
    ) async throws {
        database.setSelectedUSExaminationTypeId(
            value: id,
        )
    }

    func getRecentExaminationTypeIds() async throws -> [String] {
        database.getRecentUSExaminationTypeIds()
    }

    func setRecentExaminationTypeIds(
        _ ids: [String],
    ) async throws {
        database.setRecentUSExaminationTypeIds(
            values: Array(
                ids.prefix(
                    USExaminationRecentTypes.maximumCount,
                ),
            ),
        )
    }

    func recordRecentExaminationTypeId(
        _ id: String,
    ) async throws {
        try await setRecentExaminationTypeIds(
            USExaminationRecentTypes.recording(
                id,
                in: getRecentExaminationTypeIds(),
            ),
        )
    }

    func getReports(
        limit: Int,
        offset: Int,
    ) async throws -> [USExaminationReport] {
        try await database.examinationReports.fetchExaminationReports(
            limit: limit,
            offset: offset,
        ) { models in
            models.map {
                USExaminationReport.fromDB(
                    $0,
                )
            }
        }
    }

    func interruptPendingGenerations() async throws {
        try await database.examinationReports.updateGenerations(
            fromStatus: USReportGenerationStatus.generating.rawValue,
            toStatus: USReportGenerationStatus.interrupted.rawValue,
        )
    }

    func getReportsCount() async throws -> Int {
        try await database.examinationReports.fetchExaminationReportsCount()
    }

    func setReport(
        report: USExaminationReport,
    ) async throws {
        try await database.examinationReports.setExaminationReport(
            value: report.toDB(),
        )
    }

    func updateGeneratedReport(
        report: USExaminationReport,
    ) async throws {
        guard let generationId = report.actualModelReport.generation.id else {
            return
        }
        try await database.examinationReports.updateGeneratedReport(
            reportId: report.id,
            generationId: generationId,
            value: report.actualModelReport.toDB(),
        )
    }

    func updateReport(
        report: USExaminationReport,
    ) async throws {
        try await database.examinationReports.updateExaminationReport(
            value: report.toDB(),
        )
    }

    func clearAllReports() async throws {
        try await database.examinationReports.clearAllExaminationReports()
    }

    @MainActor func clearAll() async throws {
        try await database.clearAll()
    }

    func parseDictation(
        selectedNeuralModelId: String?,
        examinationTypeId: String,
        transcript: String,
    ) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO {
        let request = USVoiceFormParseRequest(
            selectedNeuralModelId: selectedNeuralModelId,
            usExaminationTypeId: examinationTypeId,
            transcript: transcript,
        )
        return try await httpClient.post(
            endPoint: "/ultrasound/parse_dictation",
            body: request,
        )
    }
}

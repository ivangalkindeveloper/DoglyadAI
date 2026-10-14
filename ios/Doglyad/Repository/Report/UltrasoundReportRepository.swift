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
}

extension UltrasoundReportRepository {
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
                    RecentUSExaminationTypes.maximumCount,
                ),
            ),
        )
    }

    func recordRecentExaminationTypeId(
        _ id: String,
    ) async throws {
        try await setRecentExaminationTypeIds(
            RecentUSExaminationTypes.recording(
                id,
                in: getRecentExaminationTypeIds(),
            ),
        )
    }
}

extension UltrasoundReportRepository {
    static let reportEndpoint = "/ultrasound/generate_report"
    static let voiceParseEndpoint = "/ultrasound/parse_dictation"

    func parseDictation(
        locale: Locale,
        examinationTypeId: String,
        transcript: String,
    ) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO {
        let request = USVoiceFormParseRequestDTO(
            usExaminationTypeId: examinationTypeId,
            transcript: transcript,
        )
        return try await httpClient.post(
            endPoint: Self.voiceParseEndpoint,
            body: request,
            headers: [DHttpHeader.acceptLanguage: locale.identifier],
            encoderUserInfo: nil,
        )
    }

    func generateReport(
        locale: Locale,
        request: USExaminationRequest,
        scanPhotoEncodingOptions: ScanPhotoEncodingOptions,
    ) async throws -> USExaminationModelReport {
        try await httpClient.post(
            endPoint: Self.reportEndpoint,
            body: request,
            headers: [
                DHttpHeader.acceptLanguage: locale.identifier,
            ],
            encoderUserInfo: [
                .scanPhotoEncodingOptions: scanPhotoEncodingOptions,
            ],
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
            models.map { USExaminationReport.fromDB(
                $0,
            ) }
        }
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
}

extension UltrasoundReportRepository {
    @MainActor func clearAll() async throws {
        try await database.clearAll()
    }
}

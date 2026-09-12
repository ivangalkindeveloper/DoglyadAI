import DoglyadDatabase
import DoglyadNetwork
import Foundation

final class UltrasoundReportRepository: UltrasoundReportRepositoryProtocol {
    let database: DDatabaseProtocol
    let httpClient: DHttpClientProtocol

    init(
        database: DDatabaseProtocol,
        httpClient: DHttpClientProtocol
    ) {
        self.database = database
        self.httpClient = httpClient
    }
}

extension UltrasoundReportRepository {
    func getSelectedExaminationTypeId() -> String? {
        database.getSelectedUSExaminationTypeId()
    }

    func setSelectedExaminationTypeId(
        id: String
    ) {
        database.setSelectedUSExaminationTypeId(
            value: id
        )
    }

    func getRecentExaminationTypeIds() -> [String] {
        database.getRecentUSExaminationTypeIds()
    }

    func setRecentExaminationTypeIds(_ ids: [String]) {
        database.setRecentUSExaminationTypeIds(values: Array(ids.prefix(RecentUSExaminationTypes.maximumCount)))
    }

    func recordRecentExaminationTypeId(_ id: String) {
        setRecentExaminationTypeIds(
            RecentUSExaminationTypes.recording(
                id,
                in: getRecentExaminationTypeIds()
            )
        )
    }
}

extension UltrasoundReportRepository {
    static let reportEndpoint = "/ultrasound/generate_report"

    func generateReport(
        locale: Locale,
        request: USExaminationRequest,
        scanPhotoEncodingOptions: ScanPhotoEncodingOptions
    ) async throws -> USExaminationModelReport {
        try await httpClient.post(
            endPoint: Self.reportEndpoint,
            body: request,
            headers: [
                DHttpHeader.acceptLanguage: locale.identifier,
            ],
            encoderUserInfo: [
                .scanPhotoEncodingOptions: scanPhotoEncodingOptions,
            ]
        )
    }

    func getReports(
        limit: Int,
        offset: Int
    ) async -> [USExaminationReport] {
        await database.examinationReports.fetchExaminationReports(
            limit: limit,
            offset: offset
        ) { models in
            models.map { USExaminationReport.fromDB($0) }
        }
    }

    func getReportsCount() async -> Int {
        await database.examinationReports.fetchExaminationReportsCount()
    }

    func setReport(
        report: USExaminationReport
    ) async {
        try? await database.examinationReports.setExaminationReport(
            value: report.toDB()
        )
    }

    func updateReport(
        report: USExaminationReport
    ) async {
        try? await database.examinationReports.updateExaminationReport(
            value: report.toDB()
        )
    }

    func clearAllReports() async {
        try? await database.examinationReports.clearAllExaminationReports()
    }
}

extension UltrasoundReportRepository {
    @MainActor func clearAll() async {
        await database.clearAll()
    }
}

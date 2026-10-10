import DoglyadDatabase
import DoglyadNeuralModel
import Foundation

protocol UltrasoundReportRepositoryProtocol: AnyObject, DNeuralUltrasoundServerTransportProtocol {
    func getSelectedExaminationTypeId() -> String?

    func setSelectedExaminationTypeId(
        id: String,
    )

    func getRecentExaminationTypeIds() -> [String]

    func setRecentExaminationTypeIds(
        _ ids: [String],
    )

    func recordRecentExaminationTypeId(
        _ id: String,
    )

    func generateReport(
        locale: Locale,
        request: USExaminationRequest,
        scanPhotoEncodingOptions: ScanPhotoEncodingOptions,
    ) async throws -> USExaminationModelReport

    func getReports(
        limit: Int,
        offset: Int,
    ) async -> [USExaminationReport]

    func getReportsCount() async -> Int

    func setReport(
        report: USExaminationReport,
    ) async

    func updateReport(
        report: USExaminationReport,
    ) async

    func clearAllReports() async

    @MainActor func clearAll() async
}

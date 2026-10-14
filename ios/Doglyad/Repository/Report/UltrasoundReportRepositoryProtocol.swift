import DoglyadDatabase
import DoglyadNeuralModel
import Foundation

protocol UltrasoundReportRepositoryProtocol: AnyObject, DNeuralUltrasoundServerTransportProtocol {
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

    func generateReport(
        locale: Locale,
        request: USExaminationRequest,
        scanPhotoEncodingOptions: ScanPhotoEncodingOptions,
    ) async throws -> USExaminationModelReport

    func getReports(
        limit: Int,
        offset: Int,
    ) async throws -> [USExaminationReport]

    func getReportsCount() async throws -> Int

    func setReport(
        report: USExaminationReport,
    ) async throws

    func updateReport(
        report: USExaminationReport,
    ) async throws

    func clearAllReports() async throws

    @MainActor func clearAll() async throws
}

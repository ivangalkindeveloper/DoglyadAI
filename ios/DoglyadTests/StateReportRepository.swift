@testable import Doglyad
import DoglyadNeuralModel
import Foundation

@MainActor
final class StateReportRepository: UltrasoundReportRepositoryProtocol {
    var isSaveFailed = true
    private(set) var generationCount = 0
    private(set) var saveCount = 0
    private(set) var reports: [USExaminationReport] = []

    func getSelectedExaminationTypeId() async throws -> String? { nil }
    func setSelectedExaminationTypeId(
        id _: String,
    ) async throws {}
    func getRecentExaminationTypeIds() async throws -> [String] { [] }
    func setRecentExaminationTypeIds(
        _: [String],
    ) async throws {}
    func recordRecentExaminationTypeId(
        _: String,
    ) async throws {}

    func generateReport(
        locale _: Locale,
        request _: USExaminationRequest,
        scanPhotoEncodingOptions _: ScanPhotoEncodingOptions,
    ) async throws -> USExaminationModelReport {
        generationCount += 1
        throw CocoaError(
            .coderInvalidValue,
        )
    }

    func parseDictation(
        locale _: Locale,
        examinationTypeId _: String,
        transcript _: String,
    ) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO {
        throw CocoaError(
            .coderInvalidValue,
        )
    }

    func getReports(
        limit _: Int,
        offset _: Int,
    ) async throws -> [USExaminationReport] { reports }
    func getReportsCount() async throws -> Int { reports.count }

    func setReport(
        report: USExaminationReport,
    ) async throws {
        saveCount += 1
        guard !isSaveFailed else { throw CocoaError(
            .fileWriteUnknown,
        ) }
        reports.append(
            report,
        )
    }

    func updateReport(
        report: USExaminationReport,
    ) async throws {
        try await setReport(
            report: report,
        )
    }

    func clearAllReports() async throws { reports.removeAll() }
    func clearAll() async throws { reports.removeAll() }
}

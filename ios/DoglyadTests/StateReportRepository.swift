@testable import Doglyad
import DoglyadNetwork
import DoglyadNeuralModel
import Foundation

@MainActor
final class StateReportRepository: UltrasoundReportRepositoryProtocol {
    var isReportsReadFailed = false
    var failedReportsOffset: Int?
    var isSaveFailed = true
    var isGeneratedSaveFailed = false
    var isSelectionSaveFailed = false
    var isSelectionReadFailed = false
    var isRecentTypesReadFailed = false
    var isRecentTypesWriteFailed = false
    var isReportCountReadFailed = false
    var onRecentTypeRecord: (() async throws -> Void)?
    var isServerGenerating = false
    var eventContinuation: AsyncThrowingStream<DServerEvent, Error>.Continuation?
    private(set) var generationCount = 0
    private(set) var saveCount = 0
    private(set) var selectionSaveCount = 0
    private(set) var selectedExaminationTypeId: String?
    private(set) var recentExaminationTypeIds: [String] = []
    private(set) var reports: [USExaminationReport] = []

    func prepareGeneration(
        request: USReportGenerationRequest,
        photoOptions _: ScanPhotoEncodingOptions,
    ) async throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(
            request,
        )
    }

    func startGeneration(
        data _: Data,
    ) async throws -> USReportGenerationResponse {
        throw URLError(
            .unsupportedURL,
        )
    }

    func generation(
        id: UUID,
    ) async throws -> USReportGenerationResponse {
        generationCount += 1
        let report = USExaminationModelReport(
            date: Date(),
            modelId: "test",
            description: "Synthetic result",
            conclusion: "Synthetic conclusion",
            recommendations: nil,
        )
        return USReportGenerationResponse(
            modelId: "test",
            generationId: id,
            status: isServerGenerating ? .generating : .completed,
            sequence: isServerGenerating ? 1 : 2,
            partialReport: USReportPreviewResponse(
                description: nil,
                conclusion: nil,
                recommendations: nil,
                descriptionRemarks: nil,
            ),
            report: isServerGenerating ? nil : report,
            errorCode: nil,
        )
    }

    func generationEvents(
        id _: UUID,
    ) async throws -> AsyncThrowingStream<DServerEvent, Error> {
        AsyncThrowingStream { continuation in
            eventContinuation = continuation
        }
    }

    func cancelGeneration(
        id _: UUID,
    ) async throws -> USReportGenerationResponse {
        throw URLError(
            .unsupportedURL,
        )
    }

    func getSelectedExaminationTypeId() async throws -> String? {
        guard !isSelectionReadFailed else {
            throw CocoaError(
                .fileReadUnknown,
            )
        }
        return selectedExaminationTypeId
    }

    func setSelectedExaminationTypeId(
        id: String,
    ) async throws {
        selectionSaveCount += 1
        guard !isSelectionSaveFailed else {
            throw CocoaError(
                .fileWriteUnknown,
            )
        }
        selectedExaminationTypeId = id
    }

    func getRecentExaminationTypeIds() async throws -> [String] {
        guard !isRecentTypesReadFailed else {
            throw CocoaError(
                .fileReadUnknown,
            )
        }
        return recentExaminationTypeIds
    }

    func setRecentExaminationTypeIds(
        _ ids: [String],
    ) async throws {
        recentExaminationTypeIds = ids
    }

    func recordRecentExaminationTypeId(
        _ id: String,
    ) async throws {
        try await onRecentTypeRecord?()
        guard !isRecentTypesWriteFailed else {
            throw CocoaError(
                .fileWriteUnknown,
            )
        }
        recentExaminationTypeIds = USExaminationRecentTypes.recording(
            id,
            in: recentExaminationTypeIds,
        )
    }

    func getReports(
        limit: Int,
        offset: Int,
    ) async throws -> [USExaminationReport] {
        if isReportsReadFailed || failedReportsOffset == offset {
            throw CocoaError(
                .fileReadUnknown,
            )
        }
        return Array(
            reports.dropFirst(
                offset,
            ).prefix(
                limit,
            ),
        )
    }

    func interruptPendingGenerations() async throws {
        reports = reports.map { report in
            guard report.actualModelReport.generation.status == .generating else {
                return report
            }
            var model = report.actualModelReport
            model.generation.status = .interrupted
            return report.replacingModelReport(
                model,
            )
        }
    }

    func getReportsCount() async throws -> Int {
        guard !isReportCountReadFailed else {
            throw CocoaError(
                .fileReadUnknown,
            )
        }
        return reports.count
    }

    func setReport(
        report: USExaminationReport,
    ) async throws {
        saveCount += 1
        guard !isSaveFailed else {
            throw CocoaError(
                .fileWriteUnknown,
            )
        }
        reports.append(
            report,
        )
    }

    func updateGeneratedReport(
        report: USExaminationReport,
    ) async throws {
        guard !isGeneratedSaveFailed else {
            saveCount += 1
            throw CocoaError(
                .fileWriteUnknown,
            )
        }
        try await updateReport(
            report: report,
        )
    }

    func updateReport(
        report: USExaminationReport,
    ) async throws {
        saveCount += 1
        guard !isSaveFailed else {
            throw CocoaError(
                .fileWriteUnknown,
            )
        }
        if let index = reports.firstIndex(
            where: {
                $0.id == report.id
            },
        ) {
            reports[
                index,
            ] = report
        }
    }

    func clearAllReports() async throws {
        reports.removeAll()
    }

    func clearAll() async throws {
        reports.removeAll()
    }

    func parseDictation(
        selectedNeuralModelId _: String?,
        examinationTypeId _: String,
        transcript _: String,
    ) async throws -> DNeuralUltrasoundVoiceFormParseResponseDTO {
        throw CocoaError(
            .coderInvalidValue,
        )
    }
}

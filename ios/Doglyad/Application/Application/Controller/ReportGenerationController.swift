import Combine
import DoglyadNetwork
import Foundation
import OSLog

@MainActor
final class ReportGenerationController: ObservableObject {
    private static let logger = Logger(
        subsystem: "Doglyad",
        category: "ReportGeneration",
    )
    private let repository: UltrasoundReportRepositoryProtocol
    private let photoOptions: ScanPhotoEncodingOptions
    let terminalEvents = PassthroughSubject<Void, Never>()
    private let changes = PassthroughSubject<USExaminationReport, Never>()
    private var savedModels: [UUID: USExaminationModelReport] = [:]
    private var reports: [UUID: USExaminationReport] = [:]
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var savingTasks: [UUID: Task<Void, Never>] = [:]
    private var isInBackground = false
    private var suspendedReportIDs: Set<UUID> = []
    private var replacingReportIDs: Set<UUID> = []

    init(
        repository: UltrasoundReportRepositoryProtocol,
        photoOptions: ScanPhotoEncodingOptions,
    ) {
        self.repository = repository
        self.photoOptions = photoOptions
    }

    func observe(
        _ observer: @escaping (USExaminationReport) -> Void,
    ) -> AnyCancellable {
        changes.sink(
            receiveValue: observer,
        )
    }

    func current(
        _ report: USExaminationReport,
    ) -> USExaminationReport {
        if let active = reports[
            report.id,
        ] {
            return active
        }
        guard var model = savedModels[
            report.id,
        ],
            model.generation.id == report.actualModelReport.generation.id,
            model.generation.sequence >= report.actualModelReport.generation.sequence
        else {
            return report
        }
        model.generation.requestData = report.actualModelReport.generation.requestData
        return report.replacingModelReport(
            model,
        )
    }

    func start(
        request: USExaminationRequest,
        replacing original: USExaminationReport?,
    ) async throws -> USExaminationReport {
        let original = original.map(
            current,
        )
        let generationId = UUID()
        let data = try await repository.prepareGeneration(
            request: USReportGenerationRequest(
                requestId: generationId,
                examination: request,
                replacesGenerationId: original?.actualModelReport.generation.id,
            ),
            photoOptions: photoOptions,
        )
        let model = USExaminationModelReport(
            date: Date(),
            modelId: request.settingsAI.selectedNeuralModelId ?? "",
            description: "",
            conclusion: "",
            recommendations: nil,
            generation: USReportGeneration(
                status: .generating,
                id: generationId,
                requestData: data,
            ),
        )
        let report = original?.replacingModelReport(
            model,
            isNewAttempt: true,
            settings: request.settingsAI,
        ) ?? USExaminationReport(
            date: Date(),
            settingsAI: request.settingsAI,
            examinationData: request.examinationData,
            actualModelReport: model,
            previousModelReports: [],
        )
        // Stop older local writes before replacing the attempt in the database.
        replacingReportIDs.insert(
            report.id,
        )
        defer {
            replacingReportIDs.remove(
                report.id,
            )
        }
        suspendedReportIDs.remove(
            report.id,
        )
        tasks[
            report.id,
        ]?.cancel()
        await tasks[
            report.id,
        ]?.value
        tasks[
            report.id,
        ] = nil
        savingTasks[
            report.id,
        ]?.cancel()
        await savingTasks[
            report.id,
        ]?.value
        savingTasks[
            report.id,
        ] = nil
        // Persist before any network side effect. A failed save leaves the Scan draft intact.
        do {
            if original == nil {
                try await repository.setReport(
                    report: report,
                )
            } else {
                try await repository.updateReport(
                    report: report,
                )
            }
        } catch {
            replacingReportIDs.remove(
                report.id,
            )
            if let original, original.actualModelReport.generation.status.isRecoverable {
                launch(
                    original,
                )
            }
            throw error
        }
        replacingReportIDs.remove(
            report.id,
        )
        publish(
            report,
        )
        launch(
            report,
        )
        return report
    }

    func retry(
        _ original: USExaminationReport,
    ) async throws -> USExaminationReport {
        let report = current(
            original,
        )
        if reports[
            report.id,
        ] == nil {
            publish(
                report,
            )
        }
        guard let id = report.actualModelReport.generation.id,
              let data = report.actualModelReport.generation.requestData
        else {
            throw URLError(
                .cannotDecodeContentData,
            )
        }
        do {
            let result = try await repository.generation(
                id: id,
            )
            switch result.status {
            case .completed:
                try await apply(
                    result,
                    to: report.id,
                )
                return current(
                    report,
                )
            case .queued, .generating:
                launch(
                    report,
                )
                return current(
                    report,
                )
            case .failed, .cancelled: break
            }
        } catch {
            guard DHttpFailure.statusCode(
                for: error,
            ) == 404 else {
                throw error
            }
        }
        if report.actualModelReport.generation.sequence < 0 {
            launch(
                report,
            )
            return current(
                report,
            )
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let request = try decoder.decode(
            USReportGenerationRequest.self,
            from: data,
        )
        return try await start(
            request: request.examination,
            replacing: report,
        )
    }

    func setInBackground(
        _ isInBackground: Bool,
    ) {
        self.isInBackground = isInBackground
        if isInBackground {
            // iOS can suspend network delivery. Keep the attempt generating on disk.
            suspendedReportIDs.formUnion(
                tasks.keys,
            )
            for task in tasks.values {
                task.cancel()
            }
        } else {
            for report in Array(
                reports.values,
            ) where report.actualModelReport.generation.status == .generating {
                launch(
                    report,
                )
            }
        }
    }

    private func launch(
        _ report: USExaminationReport,
    ) {
        guard !isInBackground, !replacingReportIDs.contains(
            report.id,
        ), tasks[
            report.id,
        ] == nil else {
            return
        }
        suspendedReportIDs.remove(
            report.id,
        )
        reports[
            report.id,
        ] = report
        tasks[
            report.id,
        ] = Task { [weak self] in
            guard let self else {
                return
            }
            await receive(
                report.id,
            )
            tasks[
                report.id,
            ] = nil
            // A quick return can precede cancellation of the old stream.
            if Task.isCancelled, !isInBackground, suspendedReportIDs.contains(
                report.id,
            ),
                let pending = reports[
                    report.id,
                ], pending.actualModelReport.generation.status == .generating
            {
                launch(
                    pending,
                )
            }
        }
    }

    private func receive(
        _ reportId: UUID,
    ) async {
        guard let initial = reports[
            reportId,
        ], let id = initial.actualModelReport.generation.id else {
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for attempt in 0 ..< 5 {
            do {
                try Task.checkCancellation()
                let snapshot: USReportGenerationResponse
                do {
                    snapshot = try await repository.generation(
                        id: id,
                    )
                } catch {
                    guard DHttpFailure.statusCode(
                        for: error,
                    ) == 404,
                        initial.actualModelReport.generation.sequence < 0,
                        let data = initial.actualModelReport.generation.requestData
                    else {
                        throw error
                    }
                    snapshot = try await repository.startGeneration(
                        data: data,
                    )
                }
                try await apply(
                    snapshot,
                    to: reportId,
                )
                if isTerminal(
                    snapshot.status,
                ) {
                    return
                }
                let stream = try await repository.generationEvents(
                    id: id,
                )
                for try await event in stream {
                    try Task.checkCancellation()
                    if event.event == "heartbeat" {
                        continue
                    }
                    let update = try decoder.decode(
                        USReportGenerationResponse.self,
                        from: event.data,
                    )
                    try await apply(
                        update,
                        to: reportId,
                    )
                    if isTerminal(
                        update.status,
                    ) {
                        return
                    }
                }
                throw URLError(
                    .networkConnectionLost,
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                if let status = DHttpFailure.statusCode(
                    for: error,
                ), (400 ..< 500).contains(
                    status,
                ), status != 408, status != 429 {
                    break
                }
                if attempt < 4 {
                    do {
                        try await Task.sleep(
                            for: .seconds(
                                min(
                                    1 << attempt,
                                    8,
                                ),
                            ),
                        )
                    } catch {
                        return
                    }
                }
            }
        }
        guard let report = reports[
            reportId,
        ], report.actualModelReport.generation.id == id else {
            return
        }
        var model = report.actualModelReport
        model.generation.status = .interrupted
        publish(
            report.replacingModelReport(
                model,
            ),
        )
        scheduleSave(
            reportId,
        )
    }

    private func isTerminal(
        _ status: USReportGenerationServerStatus,
    ) -> Bool {
        switch status {
        case .queued, .generating: false
        case .completed, .failed, .cancelled: true
        }
    }

    private func apply(
        _ result: USReportGenerationResponse,
        to reportId: UUID,
    ) async throws {
        try Task.checkCancellation()
        guard let report = reports[
            reportId,
        ], report.actualModelReport.generation.id == result.generationId else {
            return
        }
        guard report.actualModelReport.modelId.isEmpty || report.actualModelReport.modelId == result.modelId else {
            throw URLError(
                .cannotParseResponse,
            )
        }
        guard result.sequence >= report.actualModelReport.generation.sequence else {
            return
        }
        var model: USExaminationModelReport
        switch result.status {
        case .completed:
            guard let complete = result.report, complete.modelId == result.modelId else {
                throw URLError(
                    .cannotParseResponse,
                )
            }
            model = complete
            model.generation.status = .completed
        case .queued, .generating, .failed, .cancelled:
            let partial = result.partialReport
            model = USExaminationModelReport(
                id: report.actualModelReport.id,
                date: report.actualModelReport.date,
                modelId: result.modelId,
                description: partial.description ?? "",
                conclusion: partial.conclusion ?? "",
                recommendations: partial.recommendations,
                descriptionRemarks: partial.descriptionRemarks,
            )
            switch result.status {
            case .queued, .generating: model.generation.status = .generating
            case .failed: model.generation.status = .failed
            case .cancelled: model.generation.status = .cancelled
            case .completed: break
            }
        }
        model.id = report.actualModelReport.id
        model.generation.id = result.generationId
        model.generation.sequence = result.sequence
        model.generation.requestData = report.actualModelReport.generation.requestData
        publish(
            report.replacingModelReport(
                model,
            ),
        )
        scheduleSave(
            reportId,
        )
    }

    private func publish(
        _ report: USExaminationReport,
    ) {
        let previous = reports[
            report.id,
        ]?.actualModelReport
        reports[
            report.id,
        ] = report
        changes.send(
            report,
        )
        if previous?.generation.status != report.actualModelReport.generation.status {
            switch report.actualModelReport.generation.status {
            case .completed, .failed, .cancelled: terminalEvents.send()
            case .generating, .interrupted: break
            }
        }
    }

    private func releaseSavedReport(
        _ report: USExaminationReport,
    ) {
        guard report.actualModelReport.generation.status != .generating else {
            return
        }
        var model = report.actualModelReport
        // Keep recent presentation results without retaining photographs or upload bodies.
        model.generation.requestData = nil
        savedModels[
            report.id,
        ] = model
        reports[
            report.id,
        ] = nil
        if savedModels.count > 32, let oldest = savedModels.min(
            by: {
                $0.value.date < $1.value.date
            },
        )?.key {
            savedModels[
                oldest,
            ] = nil
        }
    }

    private func scheduleSave(
        _ reportId: UUID,
    ) {
        guard savingTasks[
            reportId,
        ] == nil else {
            return
        }
        savingTasks[
            reportId,
        ] = Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                savingTasks[
                    reportId,
                ] = nil
            }
            var failures = 0
            while !Task.isCancelled, let report = reports[
                reportId,
            ] {
                do {
                    try await repository.updateGeneratedReport(
                        report: report,
                    )
                    failures = 0
                    if reports[
                        reportId,
                    ] == report {
                        releaseSavedReport(
                            report,
                        )
                        return
                    }
                } catch {
                    guard !Task.isCancelled else {
                        return
                    }
                    failures += 1
                    if failures == 1 || failures == 5 {
                        Self.logger.error(
                            "Report history update failed; automatic retry pending. Error type: \(String(describing: type(of: error)), privacy: .public)",
                        )
                    }
                    if failures >= 5 {
                        // Continue automatic saves. Do not start inference again.
                        do {
                            try await Task.sleep(
                                for: .seconds(
                                    15,
                                ),
                            )
                        } catch {
                            return
                        }
                    }
                    do {
                        try await Task.sleep(
                            for: .seconds(
                                2,
                            ),
                        )
                    } catch {
                        return
                    }
                }
            }
        }
    }
}

import Foundation
import SwiftData

@ModelActor
public actor DExaminationReportsStore {
    public func fetchExaminationReports<T: Sendable>(
        limit: Int,
        offset: Int,
        _ transform: @Sendable ([USExaminationReportDB]) -> T,
    ) throws -> T {
        guard limit > 0 else {
            return transform(
                [],
            )
        }

        var descriptor = FetchDescriptor<USExaminationReportDB>(
            sortBy: [SortDescriptor(
                \.date,
                order: .reverse,
            )],
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = max(
            offset,
            0,
        )
        let models = try modelContext.fetch(
            descriptor,
        )
        return transform(
            models,
        )
    }

    public func updateGenerations(
        fromStatus: String,
        toStatus: String,
    ) throws {
        let descriptor = FetchDescriptor<USReportGenerationDB>(
            predicate: #Predicate {
                $0.status == fromStatus
            },
        )
        for generation in try modelContext.fetch(
            descriptor,
        ) {
            generation.status = toStatus
        }
        try saveChanges()
    }

    public func fetchExaminationReportsCount() throws -> Int {
        let descriptor = FetchDescriptor<USExaminationReportDB>()
        return try modelContext.fetchCount(
            descriptor,
        )
    }

    public func setExaminationReport(
        value: USExaminationReportDB,
    ) throws {
        modelContext.insert(
            value,
        )
        try saveChanges()
    }

    public func updateExaminationReport(
        value: USExaminationReportDB,
    ) throws {
        let id = value.id
        let descriptor = FetchDescriptor<USExaminationReportDB>(
            predicate: #Predicate<USExaminationReportDB> {
                $0.id == id
            },
        )
        guard let report = try modelContext.fetch(
            descriptor,
        ).first else {
            throw DDatabaseError.examinationReportNotFound
        }
        modelContext.delete(
            report,
        )
        modelContext.insert(
            value,
        )
        try saveChanges()
    }

    public func updateGeneratedReport(
        reportId: UUID,
        generationId: UUID,
        value: USExaminationModelReportDB,
    ) throws {
        let descriptor = FetchDescriptor<USExaminationReportDB>(
            predicate: #Predicate {
                $0.id == reportId
            },
        )
        guard let report = try modelContext.fetch(
            descriptor,
        ).first else {
            throw DDatabaseError.examinationReportNotFound
        }
        guard report.actualModelReport.generation?.id == generationId else {
            return
        }
        let previous = report.actualModelReport
        report.actualModelReport = value
        modelContext.delete(
            previous,
        )
        try saveChanges()
    }

    public func clearAllExaminationReports() throws {
        do {
            try deleteAll(
                USExaminationReportDB.self,
            )
            // Also remove records left by older schemas without cascade ownership.
            try deleteAll(
                USExaminationDataDB.self,
            )
            try deleteAll(
                SettingsAIDB.self,
            )
            try deleteAll(
                USExaminationScanPhotoDB.self,
            )
            try deleteAll(
                USExaminationModelReportDB.self,
            )
            try deleteAll(
                USExaminationPhotoRemarksDB.self,
            )
            try deleteAll(
                USExaminationPhotoRemarkPointDB.self,
            )
            try deleteAll(
                USReportGenerationDB.self,
            )
            try saveChanges()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func deleteAll<T: PersistentModel>(
        _: T.Type,
    ) throws {
        for value in try modelContext.fetch(
            FetchDescriptor<T>(),
        ) {
            modelContext.delete(
                value,
            )
        }
    }

    private func saveChanges() throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

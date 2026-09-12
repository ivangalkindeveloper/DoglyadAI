import Foundation
import SwiftData

@ModelActor
public actor DExaminationReportsStore {
    public func fetchExaminationReports<T: Sendable>(
        limit: Int,
        offset: Int,
        _ transform: @Sendable ([USExaminationReportDB]) -> T
    ) -> T {
        guard limit > 0 else {
            return transform([])
        }

        var descriptor = FetchDescriptor<USExaminationReportDB>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = max(offset, 0)
        let models = (try? modelContext.fetch(descriptor)) ?? []
        return transform(models)
    }

    public func fetchExaminationReportsCount() -> Int {
        let descriptor = FetchDescriptor<USExaminationReportDB>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    public func setExaminationReport(value: USExaminationReportDB) throws {
        modelContext.insert(value)
        try modelContext.save()
    }

    public func updateExaminationReport(value: USExaminationReportDB) throws {
        let id = value.id
        let descriptor = FetchDescriptor<USExaminationReportDB>(
            predicate: #Predicate<USExaminationReportDB> { $0.id == id }
        )
        guard let report = try? modelContext.fetch(descriptor).first else { return }
        modelContext.delete(report)
        modelContext.insert(value)
        try modelContext.save()
    }

    public func clearAllExaminationReports() throws {
        let descriptor = FetchDescriptor<USExaminationReportDB>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let reports = (try? modelContext.fetch(descriptor)) ?? []
        for report in reports {
            modelContext.delete(report)
        }
        try modelContext.save()
    }
}

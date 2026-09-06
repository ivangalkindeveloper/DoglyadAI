import Foundation
import SwiftData

@ModelActor
public actor DExaminationConclusionsStore {
    public func fetchExaminationConclusions<T: Sendable>(
        limit: Int,
        offset: Int,
        _ transform: @Sendable ([USExaminationConclusionDB]) -> T
    ) -> T {
        guard limit > 0 else {
            return transform([])
        }

        var descriptor = FetchDescriptor<USExaminationConclusionDB>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = max(offset, 0)
        let models = (try? modelContext.fetch(descriptor)) ?? []
        return transform(models)
    }

    public func fetchExaminationConclusionsCount() -> Int {
        let descriptor = FetchDescriptor<USExaminationConclusionDB>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    public func setExaminationConclusion(value: USExaminationConclusionDB) throws {
        modelContext.insert(value)
        try modelContext.save()
    }

    public func updateExaminationConclusion(value: USExaminationConclusionDB) throws {
        let id = value.id
        let descriptor = FetchDescriptor<USExaminationConclusionDB>(
            predicate: #Predicate<USExaminationConclusionDB> { $0.id == id }
        )
        guard let conclusion = try? modelContext.fetch(descriptor).first else { return }
        modelContext.delete(conclusion)
        modelContext.insert(value)
        try modelContext.save()
    }

    public func clearAllExaminationConclusions() throws {
        let descriptor = FetchDescriptor<USExaminationConclusionDB>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let conclusions = (try? modelContext.fetch(descriptor)) ?? []
        for conclusion in conclusions {
            modelContext.delete(conclusion)
        }
        try modelContext.save()
    }
}

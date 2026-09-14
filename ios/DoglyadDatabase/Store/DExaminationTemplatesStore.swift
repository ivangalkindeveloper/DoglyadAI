import Foundation
import SwiftData

@ModelActor
public actor DExaminationTemplatesStore {
    public func fetchExaminationTemplates<T: Sendable>(
        _ transform: @Sendable ([USExaminationTemplateDB]) -> T
    ) -> T {
        let descriptor = FetchDescriptor<USExaminationTemplateDB>(
            sortBy: [SortDescriptor(\.usExaminationTypeId, order: .forward)]
        )
        let models = (try? modelContext.fetch(descriptor)) ?? []
        return transform(models)
    }

    public func upsertExaminationTemplate(value: USExaminationTemplateDB) throws {
        let id = value.id
        let descriptor = FetchDescriptor<USExaminationTemplateDB>(
            predicate: #Predicate<USExaminationTemplateDB> { $0.id == id }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.usExaminationTypeId = value.usExaminationTypeId
            existing.name = value.name
            existing.content = value.content
        } else {
            modelContext.insert(value)
        }
        try modelContext.save()
    }

    public func deleteExaminationTemplate(id: UUID) throws {
        let descriptor = FetchDescriptor<USExaminationTemplateDB>(
            predicate: #Predicate<USExaminationTemplateDB> { $0.id == id }
        )
        guard let item = try? modelContext.fetch(descriptor).first else { return }
        modelContext.delete(item)
        try modelContext.save()
    }

    public func clearAllExaminationTemplates() throws {
        let descriptor = FetchDescriptor<USExaminationTemplateDB>(
            sortBy: [SortDescriptor(\.usExaminationTypeId, order: .forward)]
        )
        let items = (try? modelContext.fetch(descriptor)) ?? []
        for item in items {
            modelContext.delete(item)
        }
        try modelContext.save()
    }
}

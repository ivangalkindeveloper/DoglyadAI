@testable import Doglyad
import Foundation

@MainActor
final class DesignTemplateRepository: TemplateRepositoryProtocol {
    var isReadFailed = true
    var onRead: (() async -> Void)?
    let template: USExaminationTemplate

    init(
        template: USExaminationTemplate,
    ) {
        self.template = template
    }

    func getSelectedTemplateId() async throws -> UUID? {
        nil
    }

    func setSelectedTemplateId(
        id _: UUID,
    ) async throws {}

    func clearSelectedTemplateId() async throws {}

    func getReadyMadeTemplates() async throws -> [USExaminationReadyMadeTemplate] {
        []
    }

    func getTemplates(
        usExaminationTypesById _: [String: USExaminationType],
    ) async throws -> [USExaminationTemplate] {
        [template]
    }

    func getTemplate(
        id _: UUID,
        usExaminationTypesById _: [String: USExaminationType],
    ) async throws -> USExaminationTemplate? {
        await onRead?()
        if isReadFailed {
            throw CocoaError(
                .fileReadUnknown,
            )
        }
        return template
    }

    func saveTemplate(
        template _: USExaminationTemplate,
    ) async throws {}

    func deleteTemplate(
        id _: UUID,
    ) async throws {}
}

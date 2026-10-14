import Foundation

protocol UltrasoundDraftRepositoryProtocol: AnyObject {
    func getDraft() async throws -> USExaminationDraft?

    func saveForm(
        _ form: USExaminationDraftForm,
    ) async throws

    func savePhotos(
        _ photos: [USExaminationScanPhoto],
        currentForm: USExaminationDraftForm,
    ) async throws

    func clearDraft() async throws
}

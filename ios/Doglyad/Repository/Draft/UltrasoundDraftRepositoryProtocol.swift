import Foundation

protocol UltrasoundDraftRepositoryProtocol: AnyObject {
    func getDraft() async -> USExaminationDraft?

    func saveForm(
        _ form: USExaminationDraftForm
    ) async

    func savePhotos(
        _ photos: [USExaminationScanPhoto],
        currentForm: USExaminationDraftForm
    ) async

    func clearDraft() async
}

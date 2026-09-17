import DoglyadDatabase
import Foundation

final class UltrasoundDraftRepository: UltrasoundDraftRepositoryProtocol {
    private let database: DDatabaseProtocol

    init(
        database: DDatabaseProtocol
    ) {
        self.database = database
    }

    func getDraft() async -> USExaminationDraft? {
        await database.examinationDraft.fetchDraft { draft in
            draft.map { USExaminationDraft.fromDB($0) }
        }
    }

    func saveForm(
        _ form: USExaminationDraftForm
    ) async {
        try? await database.examinationDraft.upsertDraftForm(
            value: form.toDB()
        )
    }

    func savePhotos(
        _ photos: [USExaminationScanPhoto],
        currentForm: USExaminationDraftForm
    ) async {
        let values = photos.toDraftDB()
        try? await database.examinationDraft.replaceDraftPhotos(
            values: values,
            currentForm: currentForm.toDB()
        )
    }

    func clearDraft() async {
        try? await database.examinationDraft.clearDraft()
    }
}

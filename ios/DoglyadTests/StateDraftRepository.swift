@testable import Doglyad
import Foundation

@MainActor
final class StateDraftRepository: UltrasoundDraftRepositoryProtocol {
    var isReadFailed = false
    var draft: USExaminationDraft?
    var onRead: (() async throws -> USExaminationDraft?)?
    var onClear: (() async throws -> Void)?
    private(set) var savedForms: [USExaminationDraftForm] = []
    private(set) var savedPhotos: [[USExaminationScanPhoto]] = []
    private(set) var clearCount = 0

    func getDraft() async throws -> USExaminationDraft? {
        if let onRead {
            return try await onRead()
        }
        if isReadFailed {
            throw CocoaError(
                .fileReadUnknown,
            )
        }
        return draft
    }

    func saveForm(
        _ form: USExaminationDraftForm,
    ) async throws {
        savedForms.append(
            form,
        )
        draft = USExaminationDraft(
            form: form,
            photos: draft?.photos ?? [],
        )
    }

    func savePhotos(
        _ photos: [USExaminationScanPhoto],
        currentForm: USExaminationDraftForm,
    ) async throws {
        savedPhotos.append(
            photos,
        )
        draft = USExaminationDraft(
            form: draft?.form ?? currentForm,
            photos: photos,
        )
    }

    func clearDraft() async throws {
        clearCount += 1
        try await onClear?()
        draft = nil
    }
}

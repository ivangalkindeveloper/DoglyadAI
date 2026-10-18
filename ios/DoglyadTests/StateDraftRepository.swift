@testable import Doglyad

@MainActor
final class StateDraftRepository: UltrasoundDraftRepositoryProtocol {
    private(set) var clearCount = 0

    func getDraft() async throws -> USExaminationDraft? { nil }

    func saveForm(
        _: USExaminationDraftForm,
    ) async throws {}

    func savePhotos(
        _: [USExaminationScanPhoto],
        currentForm _: USExaminationDraftForm,
    ) async throws {}

    func clearDraft() async throws { clearCount += 1 }
}

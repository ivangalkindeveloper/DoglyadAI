import Foundation

@MainActor
final class ScanGeneratingState: ScanStateProtocol {
    let snapshot: USExaminationDraftForm

    init(
        snapshot: USExaminationDraftForm,
    ) {
        self.snapshot = snapshot
    }
}

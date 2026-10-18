import Foundation

@MainActor
final class ScanGeneratingState: ScanStateProtocol, @MainActor Equatable {
    let snapshot: USExaminationDraftForm

    init(
        snapshot: USExaminationDraftForm,
    ) {
        self.snapshot = snapshot
    }

    static func == (
        lhs: ScanGeneratingState,
        rhs: ScanGeneratingState,
    ) -> Bool {
        lhs.snapshot == rhs.snapshot
    }
}

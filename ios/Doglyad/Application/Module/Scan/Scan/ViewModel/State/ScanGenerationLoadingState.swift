import Foundation

@MainActor
final class ScanGenerationLoadingState: ScanStateProtocol, @MainActor Equatable {
    let snapshot: USExaminationDraftForm

    init(
        snapshot: USExaminationDraftForm,
    ) {
        self.snapshot = snapshot
    }

    static func == (
        lhs: ScanGenerationLoadingState,
        rhs: ScanGenerationLoadingState,
    ) -> Bool {
        lhs.snapshot == rhs.snapshot
    }
}

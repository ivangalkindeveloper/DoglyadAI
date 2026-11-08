import Foundation

@MainActor
final class SelectUSExaminationTypeSelectionLoadingState: SelectUSExaminationTypeStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectUSExaminationTypeSelectionLoadingState,
        _: SelectUSExaminationTypeSelectionLoadingState,
    ) -> Bool {
        true
    }
}

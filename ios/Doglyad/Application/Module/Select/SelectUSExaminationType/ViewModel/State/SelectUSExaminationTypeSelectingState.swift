import Foundation

@MainActor
final class SelectUSExaminationTypeSelectingState: SelectUSExaminationTypeStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectUSExaminationTypeSelectingState,
        _: SelectUSExaminationTypeSelectingState,
    ) -> Bool {
        true
    }
}

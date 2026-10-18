import Foundation

@MainActor
final class SelectUSExaminationTypeLoadingState: SelectUSExaminationTypeStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectUSExaminationTypeLoadingState,
        _: SelectUSExaminationTypeLoadingState,
    ) -> Bool {
        true
    }
}

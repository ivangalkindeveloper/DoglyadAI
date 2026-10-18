import Foundation

@MainActor
final class SelectUSExaminationTypeContentState: SelectUSExaminationTypeStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectUSExaminationTypeContentState,
        _: SelectUSExaminationTypeContentState,
    ) -> Bool {
        true
    }
}

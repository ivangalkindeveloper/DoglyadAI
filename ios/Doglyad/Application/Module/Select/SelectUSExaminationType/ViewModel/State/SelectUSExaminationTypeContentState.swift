import Foundation

@MainActor
final class SelectUSExaminationTypeContentState: SelectUSExaminationTypeStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: SelectUSExaminationTypeContentState,
        _: SelectUSExaminationTypeContentState,
    ) -> Bool {
        true
    }
}

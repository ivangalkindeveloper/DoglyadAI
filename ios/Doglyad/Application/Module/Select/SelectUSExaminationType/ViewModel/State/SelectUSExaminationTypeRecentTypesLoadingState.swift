import Foundation

@MainActor
final class SelectUSExaminationTypeRecentTypesLoadingState: SelectUSExaminationTypeStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectUSExaminationTypeRecentTypesLoadingState,
        _: SelectUSExaminationTypeRecentTypesLoadingState,
    ) -> Bool {
        true
    }
}

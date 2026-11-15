import Foundation

@MainActor
final class SelectUSExaminationTypeContentState: SelectUSExaminationTypeStateProtocol, @MainActor Equatable {
    let recentTypeIds: [String]
    let currentValue: USExaminationType?

    init(
        recentTypeIds: [String] = [],
        currentValue: USExaminationType? = nil,
    ) {
        self.recentTypeIds = recentTypeIds
        self.currentValue = currentValue
    }

    func copyWith(
        recentTypeIds: [String]? = nil,
        currentValue: USExaminationType?? = nil,
    ) -> SelectUSExaminationTypeContentState {
        SelectUSExaminationTypeContentState(
            recentTypeIds: recentTypeIds ?? self.recentTypeIds,
            currentValue: currentValue ?? self.currentValue,
        )
    }

    static func == (
        lhs: SelectUSExaminationTypeContentState,
        rhs: SelectUSExaminationTypeContentState,
    ) -> Bool {
        lhs.recentTypeIds == rhs.recentTypeIds && lhs.currentValue == rhs.currentValue
    }
}

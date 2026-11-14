import Foundation

@MainActor
final class OnBoardingExaminationTypeState: OnBoardingStateProtocol, @MainActor Equatable {
    let index = 3
    let primaryButtonTitleKey = L10NKey.buttonSelectType

    init() {}

    static func == (
        lhs: OnBoardingExaminationTypeState,
        rhs: OnBoardingExaminationTypeState,
    ) -> Bool {
        lhs.index == rhs.index
            && lhs.primaryButtonTitleKey == rhs.primaryButtonTitleKey
    }
}

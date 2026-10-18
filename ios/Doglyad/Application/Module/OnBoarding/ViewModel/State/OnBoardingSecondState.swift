import Foundation

@MainActor
final class OnBoardingSecondState: OnBoardingStateProtocol, @MainActor Equatable {
    let index = 1
    let primaryButtonTitleKey = L10NKey.buttonNext

    static func == (
        lhs: OnBoardingSecondState,
        rhs: OnBoardingSecondState,
    ) -> Bool {
        lhs.index == rhs.index
            && lhs.primaryButtonTitleKey == rhs.primaryButtonTitleKey
    }
}

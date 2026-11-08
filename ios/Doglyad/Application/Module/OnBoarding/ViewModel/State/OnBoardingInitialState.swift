import Foundation

@MainActor
final class OnBoardingInitialState: OnBoardingStateProtocol, @MainActor Equatable {
    let index = 0
    let primaryButtonTitleKey = L10NKey.buttonNext

    static func == (
        lhs: OnBoardingInitialState,
        rhs: OnBoardingInitialState,
    ) -> Bool {
        lhs.index == rhs.index
            && lhs.primaryButtonTitleKey == rhs.primaryButtonTitleKey
    }
}

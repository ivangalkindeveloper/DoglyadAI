import Foundation

@MainActor
final class OnBoardingCompletingState: OnBoardingStateProtocol, @MainActor Equatable {
    let index = 4
    let primaryButtonTitleKey = L10NKey.buttonStart

    static func == (
        lhs: OnBoardingCompletingState,
        rhs: OnBoardingCompletingState,
    ) -> Bool {
        lhs.index == rhs.index
            && lhs.primaryButtonTitleKey == rhs.primaryButtonTitleKey
    }
}

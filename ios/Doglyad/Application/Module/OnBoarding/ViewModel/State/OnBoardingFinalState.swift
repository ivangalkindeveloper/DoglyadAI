import Foundation

@MainActor
final class OnBoardingFinalState: OnBoardingStateProtocol, @MainActor Equatable {
    let index = 4
    let primaryButtonTitleKey = L10NKey.buttonStart

    static func == (
        lhs: OnBoardingFinalState,
        rhs: OnBoardingFinalState,
    ) -> Bool {
        lhs.index == rhs.index
            && lhs.primaryButtonTitleKey == rhs.primaryButtonTitleKey
    }
}

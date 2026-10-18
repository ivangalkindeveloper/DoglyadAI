import Foundation

@MainActor
final class OnBoardingFirstState: OnBoardingStateProtocol, @MainActor Equatable {
    let index = 0
    let primaryButtonTitleKey = L10NKey.buttonNext

    static func == (
        lhs: OnBoardingFirstState,
        rhs: OnBoardingFirstState,
    ) -> Bool {
        lhs.index == rhs.index
            && lhs.primaryButtonTitleKey == rhs.primaryButtonTitleKey
    }
}

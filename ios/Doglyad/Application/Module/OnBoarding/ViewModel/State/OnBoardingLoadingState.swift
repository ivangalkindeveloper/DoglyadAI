import Foundation

@MainActor
final class OnBoardingLoadingState: OnBoardingStateProtocol, @MainActor Equatable {
    let index = 4
    let primaryButtonTitleKey = L10NKey.buttonStart

    init() {}

    static func == (
        lhs: OnBoardingLoadingState,
        rhs: OnBoardingLoadingState,
    ) -> Bool {
        lhs.index == rhs.index
            && lhs.primaryButtonTitleKey == rhs.primaryButtonTitleKey
    }
}

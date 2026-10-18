import Foundation

@MainActor
final class OnBoardingFailedState: OnBoardingStateProtocol, @MainActor Equatable {
    let index = 4
    let primaryButtonTitleKey = L10NKey.buttonStart
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: OnBoardingFailedState,
        rhs: OnBoardingFailedState,
    ) -> Bool {
        lhs === rhs || lhs.index == rhs.index
            && lhs.primaryButtonTitleKey == rhs.primaryButtonTitleKey
            && lhs.error.isEqual(
                to: rhs.error,
            )
    }
}

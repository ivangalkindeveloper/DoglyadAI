import Foundation

@MainActor
final class OnBoardingErrorState: OnBoardingStateProtocol, @MainActor Equatable {
    let index = 4
    let primaryButtonTitleKey = L10NKey.buttonStart
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: OnBoardingErrorState,
        rhs: OnBoardingErrorState,
    ) -> Bool {
        lhs === rhs || lhs.index == rhs.index
            && lhs.primaryButtonTitleKey == rhs.primaryButtonTitleKey
            && lhs.error.isEqual(
                to: rhs.error,
            )
    }
}

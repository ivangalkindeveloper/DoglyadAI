import Foundation

@MainActor
final class OnBoardingFailedState: OnBoardingStateProtocol {
    let index = 4
    let primaryButtonTitleKey = L10NKey.buttonStart
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}

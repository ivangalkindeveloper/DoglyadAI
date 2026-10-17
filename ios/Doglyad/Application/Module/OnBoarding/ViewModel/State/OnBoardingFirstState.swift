import Foundation

@MainActor
final class OnBoardingFirstState: OnBoardingStateProtocol {
    let index = 0
    let primaryButtonTitleKey = L10NKey.buttonNext
}

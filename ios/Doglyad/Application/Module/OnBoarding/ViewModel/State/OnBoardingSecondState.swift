import Foundation

@MainActor
final class OnBoardingSecondState: OnBoardingStateProtocol {
    let index = 1
    let primaryButtonTitleKey = L10NKey.buttonNext
}

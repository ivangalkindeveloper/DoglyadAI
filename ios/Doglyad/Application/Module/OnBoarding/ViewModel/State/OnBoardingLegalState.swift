@MainActor
final class OnBoardingLegalState: OnBoardingStateProtocol {
    let index = 2
    let primaryButtonTitleKey = L10NKey.buttonAccept
    let isLegalAccepted: Bool

    init(
        isLegalAccepted: Bool = false,
    ) {
        self.isLegalAccepted = isLegalAccepted
    }
}

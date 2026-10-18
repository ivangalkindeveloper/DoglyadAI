@MainActor
final class OnBoardingLegalState: OnBoardingStateProtocol, @MainActor Equatable {
    let index = 2
    let primaryButtonTitleKey = L10NKey.buttonAccept
    let isLegalAccepted: Bool

    init(
        isLegalAccepted: Bool = false,
    ) {
        self.isLegalAccepted = isLegalAccepted
    }

    static func == (
        lhs: OnBoardingLegalState,
        rhs: OnBoardingLegalState,
    ) -> Bool {
        lhs.index == rhs.index
            && lhs.primaryButtonTitleKey == rhs.primaryButtonTitleKey
            && lhs.isLegalAccepted == rhs.isLegalAccepted
    }
}

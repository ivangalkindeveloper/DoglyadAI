@MainActor
final class PatientConsentInitialState: PatientConsentStateProtocol, @MainActor Equatable {
    let isDoNotAskAgain: Bool

    init(
        isDoNotAskAgain: Bool = false,
    ) {
        self.isDoNotAskAgain = isDoNotAskAgain
    }

    func copyWith(
        isDoNotAskAgain: Bool? = nil,
    ) -> Self {
        Self(
            isDoNotAskAgain: isDoNotAskAgain ?? self.isDoNotAskAgain,
        )
    }

    static func == (
        lhs: PatientConsentInitialState,
        rhs: PatientConsentInitialState,
    ) -> Bool {
        lhs.isDoNotAskAgain == rhs.isDoNotAskAgain
    }
}

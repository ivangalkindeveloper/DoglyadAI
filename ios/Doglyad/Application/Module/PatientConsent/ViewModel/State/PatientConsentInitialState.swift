@MainActor
final class PatientConsentInitialState: PatientConsentStateProtocol, @MainActor Equatable {
    let isDoNotAskAgain: Bool

    init(
        isDoNotAskAgain: Bool = false,
    ) {
        self.isDoNotAskAgain = isDoNotAskAgain
    }

    static func == (
        lhs: PatientConsentInitialState,
        rhs: PatientConsentInitialState,
    ) -> Bool {
        lhs.isDoNotAskAgain == rhs.isDoNotAskAgain
    }
}

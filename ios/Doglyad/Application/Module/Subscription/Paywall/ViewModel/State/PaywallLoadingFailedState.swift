@MainActor
final class PaywallLoadingFailedState: PaywallStateProtocol, @MainActor Equatable {
    let errorDescription: String

    init(
        errorDescription: String,
    ) {
        self.errorDescription = errorDescription
    }

    static func == (
        lhs: PaywallLoadingFailedState,
        rhs: PaywallLoadingFailedState,
    ) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}

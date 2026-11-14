@MainActor
final class SubscriptionRecoveryRestoreLoadingState: SubscriptionRecoveryStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: SubscriptionRecoveryRestoreLoadingState,
        _: SubscriptionRecoveryRestoreLoadingState,
    ) -> Bool {
        true
    }
}

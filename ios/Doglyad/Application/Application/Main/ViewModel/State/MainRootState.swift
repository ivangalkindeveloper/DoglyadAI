@MainActor
final class MainRootState: MainRootStateProtocol, @MainActor Equatable {
    static func == (
        _: MainRootState,
        _: MainRootState,
    ) -> Bool {
        true
    }
}

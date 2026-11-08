@MainActor
final class MainRootDefaultState: MainRootStateProtocol, @MainActor Equatable {
    static func == (
        _: MainRootDefaultState,
        _: MainRootDefaultState,
    ) -> Bool {
        true
    }
}

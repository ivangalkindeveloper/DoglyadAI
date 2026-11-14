@MainActor
final class MainRootDefaultState: MainRootStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: MainRootDefaultState,
        _: MainRootDefaultState,
    ) -> Bool {
        true
    }
}

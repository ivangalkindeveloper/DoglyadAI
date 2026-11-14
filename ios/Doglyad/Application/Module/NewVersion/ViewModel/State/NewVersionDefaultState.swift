@MainActor
final class NewVersionDefaultState: NewVersionStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: NewVersionDefaultState,
        _: NewVersionDefaultState,
    ) -> Bool {
        true
    }
}

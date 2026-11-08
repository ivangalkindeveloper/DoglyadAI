@MainActor
final class NewVersionDefaultState: NewVersionStateProtocol, @MainActor Equatable {
    static func == (
        _: NewVersionDefaultState,
        _: NewVersionDefaultState,
    ) -> Bool {
        true
    }
}

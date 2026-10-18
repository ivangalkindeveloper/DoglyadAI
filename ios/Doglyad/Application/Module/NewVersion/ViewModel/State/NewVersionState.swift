@MainActor
final class NewVersionState: NewVersionStateProtocol, @MainActor Equatable {
    static func == (
        _: NewVersionState,
        _: NewVersionState,
    ) -> Bool {
        true
    }
}

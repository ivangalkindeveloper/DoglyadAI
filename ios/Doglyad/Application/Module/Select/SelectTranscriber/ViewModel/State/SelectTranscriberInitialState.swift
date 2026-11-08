@MainActor
final class SelectTranscriberInitialState: SelectTranscriberStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectTranscriberInitialState,
        _: SelectTranscriberInitialState,
    ) -> Bool {
        true
    }
}

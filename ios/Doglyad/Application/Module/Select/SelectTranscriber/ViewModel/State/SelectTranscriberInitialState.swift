@MainActor
final class SelectTranscriberInitialState: SelectTranscriberStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: SelectTranscriberInitialState,
        _: SelectTranscriberInitialState,
    ) -> Bool {
        true
    }
}

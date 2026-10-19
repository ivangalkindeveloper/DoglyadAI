@MainActor
final class SelectTranscriberState: SelectTranscriberStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectTranscriberState,
        _: SelectTranscriberState,
    ) -> Bool { true }
}

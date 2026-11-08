@MainActor
final class UltrasoundRootInitialState: UltrasoundRootStateProtocol, @MainActor Equatable {
    static func == (
        _: UltrasoundRootInitialState,
        _: UltrasoundRootInitialState,
    ) -> Bool {
        true
    }
}

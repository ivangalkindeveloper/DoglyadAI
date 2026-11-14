@MainActor
final class UltrasoundRootInitialState: UltrasoundRootStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: UltrasoundRootInitialState,
        _: UltrasoundRootInitialState,
    ) -> Bool {
        true
    }
}

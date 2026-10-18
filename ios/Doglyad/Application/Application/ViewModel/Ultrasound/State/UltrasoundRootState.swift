@MainActor
final class UltrasoundRootState: UltrasoundRootStateProtocol, @MainActor Equatable {
    static func == (
        _: UltrasoundRootState,
        _: UltrasoundRootState,
    ) -> Bool {
        true
    }
}

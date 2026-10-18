@MainActor
final class PermissionState: PermissionStateProtocol, @MainActor Equatable {
    static func == (
        _: PermissionState,
        _: PermissionState,
    ) -> Bool {
        true
    }
}

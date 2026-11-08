@MainActor
final class PermissionDefaultState: PermissionStateProtocol, @MainActor Equatable {
    static func == (
        _: PermissionDefaultState,
        _: PermissionDefaultState,
    ) -> Bool {
        true
    }
}

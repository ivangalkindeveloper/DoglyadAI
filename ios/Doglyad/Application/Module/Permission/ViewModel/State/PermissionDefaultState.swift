@MainActor
final class PermissionDefaultState: PermissionStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: PermissionDefaultState,
        _: PermissionDefaultState,
    ) -> Bool {
        true
    }
}

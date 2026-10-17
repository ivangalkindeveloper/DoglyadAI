import Router

final class StorageClearAllArguments: RouteArgumentsProtocol {
    let onConfirm: () -> Void

    init(
        onConfirm: @escaping () -> Void,
    ) {
        self.onConfirm = onConfirm
    }
}

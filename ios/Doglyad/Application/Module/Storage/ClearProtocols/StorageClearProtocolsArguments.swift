import Router

final class StorageClearProtocolsArguments: RouteArgumentsProtocol {
    let onConfirm: () -> Void

    init(
        onConfirm: @escaping () -> Void
    ) {
        self.onConfirm = onConfirm
    }
}

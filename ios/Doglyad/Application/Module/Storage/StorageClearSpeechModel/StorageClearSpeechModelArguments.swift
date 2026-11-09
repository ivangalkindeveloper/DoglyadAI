import Router

final class StorageClearSpeechModelArguments: RouteArgumentsProtocol {
    let onConfirm: () -> Void

    init(
        onConfirm: @escaping () -> Void,
    ) {
        self.onConfirm = onConfirm
    }
}

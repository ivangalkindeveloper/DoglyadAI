import Router

final class TemplateDeleteArguments: RouteArgumentsProtocol {
    let onConfirm: () -> Void

    init(
        onConfirm: @escaping () -> Void
    ) {
        self.onConfirm = onConfirm
    }
}

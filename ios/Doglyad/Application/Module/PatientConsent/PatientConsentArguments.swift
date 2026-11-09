import Router

final class PatientConsentArguments: RouteArgumentsProtocol {
    let onConfirm: () -> Void

    init(
        onConfirm: @escaping () -> Void,
    ) {
        self.onConfirm = onConfirm
    }
}

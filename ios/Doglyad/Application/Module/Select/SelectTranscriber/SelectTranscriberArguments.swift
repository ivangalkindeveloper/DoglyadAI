import Router

final class SelectTranscriberArguments: RouteArgumentsProtocol {
    let currentValue: TranscriberType
    let onSelected: (TranscriberType) -> Void

    init(
        currentValue: TranscriberType,
        onSelected: @escaping (TranscriberType) -> Void,
    ) {
        self.currentValue = currentValue
        self.onSelected = onSelected
    }
}

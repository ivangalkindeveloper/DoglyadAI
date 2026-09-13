import DoglyadNeuralModel
import Router

final class ScanSpeechBottomSheetArguments: RouteArgumentsProtocol {
    let onComplete: ((DExaminationNeuralModelResponse) -> Void)?

    init(
        onComplete: ((DExaminationNeuralModelResponse) -> Void)?
    ) {
        self.onComplete = onComplete
    }
}

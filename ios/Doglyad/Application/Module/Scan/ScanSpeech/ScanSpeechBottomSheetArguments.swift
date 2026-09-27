import DoglyadNeuralModel
import Router

final class ScanSpeechBottomSheetArguments: RouteArgumentsProtocol {
    let examinationType: USExaminationType
    let onComplete: ((DExaminationNeuralModelResponse) -> Void)?

    init(
        examinationType: USExaminationType,
        onComplete: ((DExaminationNeuralModelResponse) -> Void)?
    ) {
        self.examinationType = examinationType
        self.onComplete = onComplete
    }
}

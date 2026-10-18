import DoglyadNeuralModel
import Router

final class ScanSpeechArguments: RouteArgumentsProtocol {
    let examinationType: USExaminationType
    let onConfirm: (([DNeuralUltrasoundVoiceFieldProposal]) -> Bool)?

    init(
        examinationType: USExaminationType,
        onConfirm: (([DNeuralUltrasoundVoiceFieldProposal]) -> Bool)?,
    ) {
        self.examinationType = examinationType
        self.onConfirm = onConfirm
    }
}

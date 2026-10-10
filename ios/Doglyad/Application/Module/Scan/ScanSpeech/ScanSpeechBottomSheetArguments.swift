import DoglyadNeuralModel
import Router

final class ScanSpeechBottomSheetArguments: RouteArgumentsProtocol {
    let examinationType: USExaminationType
    let getCurrentValue: (DNeuralUltrasoundVoiceFieldId) -> String
    let onConfirm: (([DNeuralUltrasoundVoiceFieldProposal]) -> Bool)?

    init(
        examinationType: USExaminationType,
        getCurrentValue: @escaping (DNeuralUltrasoundVoiceFieldId) -> String,
        onConfirm: (([DNeuralUltrasoundVoiceFieldProposal]) -> Bool)?,
    ) {
        self.examinationType = examinationType
        self.getCurrentValue = getCurrentValue
        self.onConfirm = onConfirm
    }
}

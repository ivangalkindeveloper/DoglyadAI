import DoglyadNeuralModel
import Router

final class ScanSpeechBottomSheetArguments: RouteArgumentsProtocol {
    let examinationType: USExaminationType
    let getCurrentValue: (VoiceFieldId) -> String
    let onConfirm: (([VoiceFieldProposal]) -> Bool)?

    init(
        examinationType: USExaminationType,
        getCurrentValue: @escaping (VoiceFieldId) -> String,
        onConfirm: (([VoiceFieldProposal]) -> Bool)?
    ) {
        self.examinationType = examinationType
        self.getCurrentValue = getCurrentValue
        self.onConfirm = onConfirm
    }
}

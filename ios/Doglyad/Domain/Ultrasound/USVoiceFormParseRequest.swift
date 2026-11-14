struct USVoiceFormParseRequest: Encodable, Sendable {
    let selectedNeuralModelId: String?
    let usExaminationTypeId: String
    let transcript: String

    init(
        selectedNeuralModelId: String?,
        usExaminationTypeId: String,
        transcript: String,
    ) {
        self.selectedNeuralModelId = selectedNeuralModelId
        self.usExaminationTypeId = usExaminationTypeId
        self.transcript = transcript
    }
}

struct USVoiceFormParseRequestDTO: Encodable, Sendable {
    let selectedNeuralModelId: String?
    let usExaminationTypeId: String
    let transcript: String
}

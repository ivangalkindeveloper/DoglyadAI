struct USVoiceFormParseRequestDTO: Encodable, Sendable {
    let usExaminationTypeId: String
    let transcript: String
}

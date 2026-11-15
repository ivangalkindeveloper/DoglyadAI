import DoglyadNeuralModel

struct USAudioParseResponse: Decodable {
    let transcript: String
    let result: DNeuralUltrasoundVoiceFormParseResponseDTO

    init(
        transcript: String,
        result: DNeuralUltrasoundVoiceFormParseResponseDTO,
    ) {
        self.transcript = transcript
        self.result = result
    }
}

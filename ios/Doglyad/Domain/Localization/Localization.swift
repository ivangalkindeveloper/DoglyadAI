struct Localization: Decodable, Sendable {
    let code: String
    let strings: [String: String]
    let voice: VoiceLocalization

    init(
        code: String,
        strings: [String: String],
        voice: VoiceLocalization,
    ) {
        self.code = code
        self.strings = strings
        self.voice = voice
    }
}

struct Localization: Decodable, Sendable {
    let code: String
    let strings: [String: String]
    let voice: VoiceLocalization
}

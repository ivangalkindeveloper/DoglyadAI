@frozen public enum VoiceGender: String, Codable, Hashable, Sendable {
    case male
    case female

    static func isIsolatedSpokenWord(_ text: String) -> Bool {
        ["male", "female", "mail", "мужчина", "женщина", "мужской", "женский"]
            .contains(text.lowercased())
    }
}

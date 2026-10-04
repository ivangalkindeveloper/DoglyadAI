import Foundation

public enum DSpeechFactory {
    @MainActor
    public static func make(
        locale: Locale,
        contextualStrings: [String]
    ) -> any DSpeechControllerProtocol {
        DSpeechControllerWhisperKit(locale: locale, contextualStrings: contextualStrings)
    }
}

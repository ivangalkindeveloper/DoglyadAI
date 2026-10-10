import Foundation

public enum DSpeechFactory {
    @MainActor
    public static func make(
        locale: Locale,
        contextualStrings: [String],
        lexiconLocalization: DSpeechLexiconLocalization,
    ) -> any DSpeechControllerProtocol {
        DSpeechControllerWhisperKit(
            locale: locale,
            contextualStrings: contextualStrings,
            lexiconLocalization: lexiconLocalization,
        )
    }
}

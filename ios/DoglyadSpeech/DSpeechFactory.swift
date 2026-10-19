import Foundation

public enum DSpeechFactory {
    @MainActor
    public static func availableAppleEngine(
        locale: Locale,
    ) async -> DSpeechEngine? {
        if #available(iOS 26.0, *), await DSpeechControllerAnalyzer.isSupported(
            locale: locale,
        ) {
            return .speechAnalyzer
        }
        guard DSpeechControllerSFSpeechRecognizer.isSupported(
            locale: locale,
        ) else { return nil }
        return .sfSpeechRecognizer
    }

    @MainActor
    public static func make(
        engine: DSpeechEngine,
        locale: Locale,
        contextualStrings: [String],
        lexiconLocalization: DSpeechLexiconLocalization,
    ) async throws -> any DSpeechControllerProtocol {
        switch engine {
        case .whisperKit:
            return DSpeechControllerWhisperKit(
                locale: locale,
                contextualStrings: contextualStrings,
                lexiconLocalization: lexiconLocalization,
            )
        case .speechAnalyzer:
            guard #available(iOS 26.0, *), await DSpeechControllerAnalyzer.isSupported(
                locale: locale,
            ) else { throw DSpeechError.unavailable }
            return DSpeechControllerAnalyzer(
                locale: locale,
                contextualStrings: contextualStrings,
                lexiconLocalization: lexiconLocalization,
            )
        case .sfSpeechRecognizer:
            guard DSpeechControllerSFSpeechRecognizer.isSupported(
                locale: locale,
            ) else { throw DSpeechError.unavailable }
            return DSpeechControllerSFSpeechRecognizer(
                locale: locale,
                contextualStrings: contextualStrings,
                lexiconLocalization: lexiconLocalization,
            )
        }
    }
}

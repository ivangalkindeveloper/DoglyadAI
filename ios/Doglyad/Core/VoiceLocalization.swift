import DoglyadNeuralModel
import DoglyadSpeech
import Foundation

/// Loads the catalog explicitly for Language.currentLocale, never the device's
/// implicit bundle language. Parsing modules receive only the decoded values.
struct VoiceLocalization: Decodable, Sendable {
    let code: String
    let dictation: DNeuralUltrasoundDictationLocalization
    let speech: DSpeechLexiconLocalization

    static func load(
        locale: Locale,
        bundle: Bundle = .main,
    ) throws -> Self {
        let code = locale.language.languageCode?.identifier ?? locale.identifier
        guard let url = bundle.url(
            forResource: "VoiceParsing",
            withExtension: "json",
            subdirectory: nil,
            localization: code,
        ) else { throw VoiceLocalizationError.missingCatalog(
            code,
        ) }
        let catalog = try JSONDecoder().decode(
            Self.self,
            from: Data(
                contentsOf: url,
            ),
        )
        guard catalog.code == code else { throw VoiceLocalizationError.missingCatalog(
            code,
        ) }
        return catalog
    }
}

@testable import Doglyad
import DoglyadNeuralModel
import DoglyadSpeech
import Foundation

/// Tests use the same bundled catalogs as the application, selected explicitly.
enum VoiceLocalizationTestSupport {
    private static let english = try! VoiceLocalization.load(
        locale: Locale(
            identifier: "en",
        ),
    )
    private static let russian = try! VoiceLocalization.load(
        locale: Locale(
            identifier: "ru",
        ),
    )

    static func dictation(
        locale: Locale,
    ) -> DNeuralUltrasoundDictationLocalization {
        catalog(
            locale: locale,
        ).dictation
    }

    static func speech(
        locale: Locale,
    ) -> DSpeechLexiconLocalization {
        catalog(
            locale: locale,
        ).speech
    }

    private static func catalog(
        locale: Locale,
    ) -> VoiceLocalization {
        switch locale.language.languageCode?.identifier {
        case "en": english
        case "ru": russian
        default: preconditionFailure(
                "Test requested an unsupported localization",
            )
        }
    }
}

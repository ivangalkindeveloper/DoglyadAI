@testable import Doglyad
import DoglyadNeuralModel
import DoglyadSpeech
import Foundation

/// Fixtures link to the backend catalogs and belong only to the test bundle.
private final class LocalizationFixtureBundleMarker {}

enum VoiceLocalizationTestSupport {
    private static let english = try! load(
        locale: Locale(
            identifier: "en",
        ),
    )
    private static let russian = try! load(
        locale: Locale(
            identifier: "ru",
        ),
    )

    static func data(
        kind: String,
        code: String,
    ) throws -> Data {
        let bundle = Bundle(
            for: LocalizationFixtureBundleMarker.self,
        )
        guard let url = bundle.url(
            forResource: "\(kind)-\(code)",
            withExtension: "json",
        ) else {
            throw CocoaError(
                .fileReadNoSuchFile,
            )
        }
        return try Data(
            contentsOf: url,
        )
    }

    static func load(
        locale: Locale,
    ) throws -> VoiceLocalization {
        let code = locale.language.languageCode?.identifier ?? locale.identifier
        return try JSONDecoder().decode(
            VoiceLocalization.self,
            from: data(
                kind: "voice",
                code: code,
            ),
        )
    }

    static func l10n(
        code: String,
    ) throws -> L10N {
        let voice = try load(
            locale: Locale(
                identifier: code,
            ),
        )
        let strings = try JSONDecoder().decode(
            [String: String].self,
            from: data(
                kind: "strings",
                code: code,
            ),
        )
        return try L10N(
            localization: Localization(
                code: code,
                strings: strings,
                voice: voice,
            ),
        )
    }

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

import Foundation

extension DNeuralVoiceGender {
    static func fromSpokenWord(
        _ text: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Self? {
        if localization.matches(
            .maleValue,
            text,
        ) { return .male }
        if localization.matches(
            .femaleValue,
            text,
        ) { return .female }
        return nil
    }

    static func isIsolatedSpokenWord(
        _ text: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        fromSpokenWord(
            text,
            localization: localization,
        ) != nil
    }
}

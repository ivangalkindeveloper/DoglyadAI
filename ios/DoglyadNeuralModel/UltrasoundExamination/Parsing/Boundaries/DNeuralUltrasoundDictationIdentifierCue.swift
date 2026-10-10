import Foundation

/// Spoken labels that explicitly bind an identifier to the examination.
enum DNeuralUltrasoundDictationIdentifierCue {
    static func pattern(
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String {
        localization.pattern(
            .identifierCue,
        )
    }
}

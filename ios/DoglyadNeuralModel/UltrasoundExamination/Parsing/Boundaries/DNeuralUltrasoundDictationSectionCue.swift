import Foundation

/// Explicit transitions between complaints, body measurements, and findings.
enum DNeuralUltrasoundDictationSectionCue {
    static func complaint(
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String {
        localization.pattern(
            .complaintCue,
        )
    }

    static func measurement(
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String {
        localization.pattern(
            .measurementCue,
        )
    }
}

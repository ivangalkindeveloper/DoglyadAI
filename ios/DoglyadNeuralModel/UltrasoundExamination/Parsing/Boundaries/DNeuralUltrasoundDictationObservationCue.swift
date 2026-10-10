import Foundation

/// Phrases that explicitly introduce ultrasound findings in a transcript.
/// The same boundary is used when extracting a finding and when checking that
/// a model quote has not omitted part of it.
enum DNeuralUltrasoundDictationObservationCue {
    static func pattern(
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String {
        localization.pattern(
            .observationCue,
        )
    }

    static func removeFraming(
        from text: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String {
        text.replacingOccurrences(
            of: #"^\s*(?:"# + localization.pattern(
                .observationFraming,
            ) + #")\s*[,.:—-]?\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive],
        )
    }
}

import Foundation

/// A new record reference after a clinical sentence is another form field,
/// not part of the ultrasound finding.
enum DNeuralUltrasoundDictationFollowingFieldCue {
    static func recordPattern(
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String {
        localization.pattern(
            .recordCue,
        )
    }

    static func patientPattern(
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String {
        localization.pattern(
            .followingPatientCue,
        )
    }

    static func isInsideDescription(
        _ text: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Bool {
        text.range(
            of: #"(?:[.;]|\n)\s*(?:"# + recordPattern(
                localization: localization,
            ) + #"|"# + patientPattern(
                localization: localization,
            ) + #")"#,
            options: [.regularExpression, .caseInsensitive],
        ) != nil
    }
}

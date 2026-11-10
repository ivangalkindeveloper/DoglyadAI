import Foundation

/// A readiness flag requires one direct statement; findings never establish it.
enum DNeuralUltrasoundPatientReadiness {
    static func parse(
        _ text: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> (isPrepared: Bool, quote: String)? {
        let fullRange = NSRange(
            text.startIndex...,
            in: text,
        )
        let source = text as NSString
        let matches: [(Bool, NSRange)] = [(true, DNeuralUltrasoundDictationLocalizationKey.patientPreparedEvidence), (false, .patientUnpreparedEvidence)].flatMap { value, key in
            guard let expression = try? NSRegularExpression(
                pattern: localization.pattern(
                    key,
                ),
                options: .caseInsensitive,
            ) else {
                return [(Bool, NSRange)]()
            }
            return expression.matches(
                in: text,
                range: fullRange,
            ).map {
                (value, $0.range)
            }
        }
        guard matches.count == 1, let (isPrepared, range) = matches.first else {
            return nil
        }
        let before = source.substring(
            to: range.location,
        ).components(
            separatedBy: CharacterSet(
                charactersIn: ".;!?\n",
            ),
        ).last ?? ""
        let after = source.substring(
            from: NSMaxRange(
                range,
            ),
        )
        let tail = after.components(
            separatedBy: CharacterSet(
                charactersIn: ".;!?\n",
            ),
        ).first ?? ""
        let quote = source.substring(
            with: range,
        )
        guard !after.trimmingCharacters(
            in: .whitespacesAndNewlines,
        ).hasPrefix(
            "?",
        ),
            !localization.matches(
                .patientReadinessUncertainty,
                before + quote + tail,
            )
        else {
            return nil
        }
        return (isPrepared, quote)
    }
}

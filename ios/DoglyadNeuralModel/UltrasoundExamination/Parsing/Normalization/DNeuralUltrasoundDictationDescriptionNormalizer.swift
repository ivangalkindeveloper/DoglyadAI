import Foundation

/// Normalizes an explicitly spoken measurement in a clinical description while
/// leaving the rest of the physician's wording intact.
enum DNeuralUltrasoundDictationDescriptionNormalizer {
    static func normalize(
        _ text: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String {
        let corrected = DNeuralUltrasoundDictationNumericCorrection.apply(
            to: text,
            localization: localization,
        )
        let unitPattern = localization.pattern(
            .descriptionUnits,
        )
        let labeledMeasurementPattern = #"(?:\s*(?<!\d)[:.,]\s*|\s+[–—-]\s+)([\p{L}\p{N}-]+(?:\s+[\p{L}\p{N}-]+){0,3})\s*("# + unitPattern + #")\b"#
        let unpunctuatedMeasurementPattern = #"\s+(\d{1,3})\s*("# + unitPattern + #")\b"#
        guard let match = uniqueMatch(
            labeledMeasurementPattern,
            in: corrected,
        )
            ?? uniqueMatch(
                unpunctuatedMeasurementPattern,
                in: corrected,
            ),
            let measurement = number(
                match.value,
                locale: locale,
                localization: localization,
            ),
            measurement.rounded() == measurement,
            let unit = measurementUnit(
                in: match.quote,
                locale: locale,
                localization: localization,
            )
        else { return corrected }
        return corrected.replacingOccurrences(
            of: match.quote,
            with: ": \(Int(measurement)) \(unit)",
        )
    }

    private static func number(
        _ text: String,
        locale: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> Double? {
        if let parsed = Double(
            text,
        ), parsed.isFinite, parsed > 0 { return parsed }
        return DNeuralSpokenCardinal.parse(
            text,
            locale: locale,
            localization: localization.numbers,
        ).map(
            Double.init,
        )
    }

    private static func measurementUnit(
        in text: String,
        locale _: Locale,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String? {
        if text.range(
            of: localization.pattern(
                .descriptionMillimeter,
            ),
            options: .regularExpression,
        ) != nil {
            return localization.shortUnits.millimeter
        }
        if text.range(
            of: localization.pattern(
                .descriptionVelocity,
            ),
            options: .regularExpression,
        ) != nil {
            return localization.shortUnits.velocity
        }
        if text.range(
            of: localization.pattern(
                .descriptionMilliliter,
            ),
            options: .regularExpression,
        ) != nil {
            return localization.shortUnits.milliliter
        }
        return nil
    }

    private static func uniqueMatch(
        _ pattern: String,
        in text: String,
    ) -> (quote: String, value: String)? {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators],
        )
        else { return nil }
        let matches = expression.matches(
            in: text,
            range: NSRange(
                text.startIndex ..< text.endIndex,
                in: text,
            ),
        )
        guard matches.count == 1, let match = matches.first,
              let quoteRange = Range(
                  match.range,
                  in: text,
              ),
              let valueRange = Range(
                  match.range(
                      at: 1,
                  ),
                  in: text,
              )
        else { return nil }
        return (String(
            text[
                quoteRange,
            ],
        ), String(
            text[
                valueRange,
            ],
        ))
    }
}

import Foundation

/// Normalizes an explicitly spoken measurement in a clinical description while
/// leaving the rest of the physician's wording intact.
enum DictationDescriptionNormalizer {
    static func normalize(_ text: String, locale: Locale) -> String {
        let corrected = DictationNumericCorrection.apply(to: text)
        let measurementPattern = #"(?:[:.,])\s*([\p{L}\p{N}-]+(?:\s+[\p{L}\p{N}-]+){0,3})\s+(millimeters?|millimetres?|mm|миллиметр(?:а|ов)?|мм|centimeters?\s+per\s+second|сантиметр(?:а|ов)?\s+в\s+секунду|millilit(?:er|re)s?|миллилитр(?:а|ов)?|ml|мл|cm/s|см/с)\b"#
        guard let match = uniqueMatch(measurementPattern, in: corrected),
              let measurement = number(match.value, locale: locale),
              measurement.rounded() == measurement,
              let unit = measurementUnit(in: match.quote, locale: locale)
        else { return corrected }
        return corrected.replacingOccurrences(
            of: match.quote,
            with: ": \(Int(measurement)) \(unit)"
        )
    }

    private static func number(_ text: String, locale: Locale) -> Double? {
        if let parsed = Double(text), parsed.isFinite, parsed > 0 { return parsed }
        return SpokenCardinal.parse(text, locale: locale).map(Double.init)
    }

    private static func measurementUnit(in text: String, locale: Locale) -> String? {
        let russian = locale.language.languageCode?.identifier == "ru"
        if text.range(of: #"(?i)(?:millimeters?|millimetres?|мм|миллиметр(?:а|ов)?)\b"#, options: .regularExpression) != nil {
            return russian ? "мм" : "mm"
        }
        if text.range(of: #"(?i)(?:centimeters?\s+per\s+second|сантиметр(?:а|ов)?\s+в\s+секунду|cm/s|см/с)\b"#, options: .regularExpression) != nil {
            return russian ? "см/с" : "cm/s"
        }
        if text.range(of: #"(?i)(?:millilit(?:er|re)s?|миллилитр(?:а|ов)?|ml|мл)\b"#, options: .regularExpression) != nil {
            return russian ? "мл" : "ml"
        }
        return nil
    }

    private static func uniqueMatch(_ pattern: String, in text: String) -> (quote: String, value: String)? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        else { return nil }
        let matches = expression.matches(in: text, range: NSRange(text.startIndex ..< text.endIndex, in: text))
        guard matches.count == 1, let match = matches.first,
              let quoteRange = Range(match.range, in: text),
              let valueRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return (String(text[quoteRange]), String(text[valueRange]))
    }
}

import Foundation

/// Verifies year-month-day dates dictated as three groups of single digits.
/// An ASR-collapsed eight-digit date is accepted only when it starts with an
/// explicit 19xx/20xx year and forms a valid ISO calendar date.
enum DictationSpokenBirthDate {
    static func parse(_ quote: String, locale: Locale) -> Date? {
        let birthCue = #"(?i)(?:date\s+of\s+birth|born|дата\s+рождения|года?\s+рождения)"#
        guard quote.range(of: birthCue, options: .regularExpression) != nil else { return nil }
        let digitsText = quote.replacingOccurrences(of: birthCue, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        // Recognizers may join adjacent dictated groups, for example
        // "1972-0802" or "2005, 0907". A four-digit year at the beginning
        // and a valid month/day make this year-first reading checkable.
        let calendarPattern = #"^((?:19|20)\d{2})[-,\s]*(\d{2})[-,\s]*(\d{2})$"#
        if let expression = try? NSRegularExpression(pattern: calendarPattern),
           let match = expression.firstMatch(
               in: digitsText, range: NSRange(digitsText.startIndex ..< digitsText.endIndex, in: digitsText)
           ),
           let year = Range(match.range(at: 1), in: digitsText),
           let month = Range(match.range(at: 2), in: digitsText),
           let day = Range(match.range(at: 3), in: digitsText)
        {
            let iso = "\(digitsText[year])-\(digitsText[month])-\(digitsText[day])"
            if let value = try? VoiceFieldValue.parse(fieldId: .patientDateOfBirth, text: iso, locale: locale),
               case let .date(date) = value
            {
                return date
            }
        }
        let groups = digitsText.split(separator: ",", omittingEmptySubsequences: false)
        guard groups.count == 3 else { return nil }
        let digits = groups.compactMap { group in
            SpokenDigitSequence.parse(
                group.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)),
                locale: locale
            )
        }
        guard digits.count == 3, digits[0].count == 4, digits[1].count == 2, digits[2].count == 2,
              let value = try? VoiceFieldValue.parse(
                  fieldId: .patientDateOfBirth,
                  text: "\(digits[0])-\(digits[1])-\(digits[2])",
                  locale: locale
              ),
              case let .date(date) = value
        else { return nil }
        return date
    }
}

import Foundation

/// Parses an explicitly spoken positive integer up to 199. It rejects extra
/// words instead of guessing where a measurement ends.
enum DNeuralSpokenCardinal {
    static func parse(
        _ text: String,
        locale: Locale,
        localization: DNeuralDictationNumberLocalization,
    ) -> Int? {
        let ones = localization.ones
        let tens = localization.tens
        let hundred = localization.hundred
        let normalized = text.lowercased(
            with: locale,
        ).replacingOccurrences(
            of: "-",
            with: " ",
        )
        .split(
            whereSeparator: \.isWhitespace,
        ).joined(
            separator: " ",
        )
        guard !normalized.isEmpty else { return nil }
        for number in 1 ... 199 {
            var remainder = number
            var parts: [String] = []
            if remainder >= 100 {
                parts.append(
                    hundred,
                )
                remainder -= 100
            }
            if remainder >= 20 {
                parts.append(
                    tens[
                        remainder / 10,
                    ],
                )
                remainder %= 10
            }
            if remainder > 0 {
                parts.append(
                    ones[
                        remainder,
                    ],
                )
            }
            if parts.joined(
                separator: " ",
            ) == normalized { return number }
        }
        return nil
    }
}

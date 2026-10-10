import Foundation

/// Interprets only explicitly spoken single digits. Cardinal numbers such as
/// "seventy two" remain unresolved because they do not establish leading zeros.
enum DNeuralSpokenDigitSequence {
    static func parse(
        _ text: String,
        locale: Locale,
        localization: DNeuralDictationNumberLocalization,
    ) -> String? {
        let words = text.lowercased(
            with: locale,
        )
        .split(
            whereSeparator: { $0.isWhitespace || ",.;:-".contains(
                $0,
            ) },
        )
        guard !words.isEmpty, words.count <= 8 else { return nil }
        let dictionary = localization.digits
        guard !dictionary.isEmpty else { return nil }
        var digits = ""
        for word in words {
            if word.count == 1, let digit = word.first, digit.isASCII, digit.isNumber {
                digits.append(
                    digit,
                )
            } else if let digit = dictionary[
                String(
                    word,
                ),
            ] {
                digits.append(
                    contentsOf: digit,
                )
            } else {
                return nil
            }
        }
        return digits
    }
}

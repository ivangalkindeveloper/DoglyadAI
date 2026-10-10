import Foundation

/// Removes an abandoned measurement only when the speaker explicitly
/// corrects it with "no" or "нет" between two numbers.
enum DNeuralUltrasoundDictationNumericCorrection {
    static func apply(
        to text: String,
        localization: DNeuralUltrasoundDictationLocalization,
    ) -> String {
        let word = localization.pattern(
            .spokenNumberWord,
        )
        let spokenNumber = "\(word)(?:\\s+\(word)){0,3}"
        let pattern = #"(?<![\p{L}\d])(?:\d+(?:[.,]\d+)?|"# + spokenNumber
            + #")\s*[,.;–—]?\s*(?:"# + localization.pattern(
                .numericCorrectionConnector,
            )
            + #")\s*[,.;–—]?\s*(\d+(?:[.,]\d+)?|"# + spokenNumber
            + #")(?=(?:"# + localization.pattern(
                .numericCorrectionUnits,
            ) + #")\b|[^\p{L}\d]|$)"#
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive,
        ) else {
            return text
        }
        let range = NSRange(
            text.startIndex ..< text.endIndex,
            in: text,
        )
        guard expression.numberOfMatches(
            in: text,
            range: range,
        ) == 1 else { return text }
        return expression.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: "$1",
        )
    }
}

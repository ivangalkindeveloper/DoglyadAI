import Foundation

/// Interprets only explicitly spoken single digits. Cardinal numbers such as
/// "seventy two" remain unresolved because they do not establish leading zeros.
enum SpokenDigitSequence {
    private static let english: [String: Character] = [
        "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
        "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
    ]

    private static let russian: [String: Character] = [
        "ноль": "0", "один": "1", "одна": "1", "два": "2", "две": "2",
        "три": "3", "четыре": "4", "пять": "5", "шесть": "6",
        "семь": "7", "восемь": "8", "девять": "9",
    ]

    static func parse(_ text: String, locale: Locale) -> String? {
        let words = text.lowercased(with: locale)
            .split(whereSeparator: { $0.isWhitespace || ",.;:-".contains($0) })
        guard !words.isEmpty, words.count <= 8 else { return nil }
        let dictionary: [String: Character] = switch locale.language.languageCode?.identifier {
        case "en": english
        case "ru": russian
        default: [:]
        }
        guard !dictionary.isEmpty else { return nil }
        var digits = ""
        for word in words {
            if word.count == 1, let digit = word.first, digit.isASCII, digit.isNumber {
                digits.append(digit)
            } else if let digit = dictionary[String(word)] {
                digits.append(digit)
            } else {
                return nil
            }
        }
        return digits
    }
}

import Foundation

/// Parses an explicitly spoken positive integer up to 199. It rejects extra
/// words instead of guessing where a measurement ends.
enum SpokenCardinal {
    private static let englishOnes = [
        "", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
        "seventeen", "eighteen", "nineteen",
    ]
    private static let russianOnes = [
        "", "один", "два", "три", "четыре", "пять", "шесть", "семь", "восемь", "девять",
        "десять", "одиннадцать", "двенадцать", "тринадцать", "четырнадцать", "пятнадцать",
        "шестнадцать", "семнадцать", "восемнадцать", "девятнадцать",
    ]
    private static let englishTens = [
        "", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety",
    ]
    private static let russianTens = [
        "", "", "двадцать", "тридцать", "сорок", "пятьдесят", "шестьдесят", "семьдесят",
        "восемьдесят", "девяносто",
    ]

    static func parse(_ text: String, locale: Locale) -> Int? {
        let ones: [String]
        let tens: [String]
        let hundred: String
        switch locale.language.languageCode?.identifier {
        case "en":
            ones = englishOnes
            tens = englishTens
            hundred = "one hundred"
        case "ru":
            ones = russianOnes
            tens = russianTens
            hundred = "сто"
        default:
            return nil
        }
        let normalized = text.lowercased(with: locale).replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !normalized.isEmpty else { return nil }
        for number in 1 ... 199 {
            var remainder = number
            var parts: [String] = []
            if remainder >= 100 {
                parts.append(hundred)
                remainder -= 100
            }
            if remainder >= 20 {
                parts.append(tens[remainder / 10])
                remainder %= 10
            }
            if remainder > 0 {
                parts.append(ones[remainder])
            }
            if parts.joined(separator: " ") == normalized { return number }
        }
        return nil
    }
}

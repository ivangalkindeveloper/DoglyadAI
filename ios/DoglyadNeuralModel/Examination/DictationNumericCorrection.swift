import Foundation

/// Removes an abandoned measurement only when the speaker explicitly
/// corrects it with "no" or "нет" between two numbers.
enum DictationNumericCorrection {
    static func apply(to text: String) -> String {
        let english = #"(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred)"#
        let russian = #"(?:ноль|один|одна|два|две|три|четыре|пять|шесть|семь|восемь|девять|десять|одиннадцать|двенадцать|тринадцать|четырнадцать|пятнадцать|шестнадцать|семнадцать|восемнадцать|девятнадцать|двадцать|тридцать|сорок|пятьдесят|шестьдесят|семьдесят|восемьдесят|девяносто|сто)"#
        let word = "(?:\(english)|\(russian))"
        let spokenNumber = "\(word)(?:\\s+\(word)){0,3}"
        let pattern = #"(?<![\p{L}\d])(?:\d+(?:[.,]\d+)?|"# + spokenNumber
            + #")\s*[,.;–—]?\s*(?:no|нет)\s*[,.;–—]?\s*(\d+(?:[.,]\d+)?|"# + spokenNumber
            + #")(?![\p{L}\d])"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard expression.numberOfMatches(in: text, range: range) == 1 else { return text }
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: "$1")
    }
}

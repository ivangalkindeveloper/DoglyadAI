import Foundation

/// Surface facts that can be compared without asking the generative model to
/// validate its own answer. Word order is retained for literal-substring checks.
struct DictationTextFacts {
    let tokens: [String]
    let sides: Set<String>
    let negationCount: Int
    let numbers: Set<Double>
    let units: Set<DictationUnit>
    let measurements: [DictationUnit: Set<Double>]
    let hasUncertaintyCue: Bool

    init(_ text: String, locale: Locale) {
        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
        let tokenList = Self.matches(#"[\p{L}\p{N}]+"#, in: normalized)
        tokens = tokenList

        var sides = Set<String>()
        for token in tokens {
            if token == "left" || token == "слева" || token.hasPrefix("лев") {
                sides.insert("left")
            }
            if token == "right" || token == "справа"
                || (token.hasPrefix("прав") && !token.hasPrefix("правиль") && !token.hasPrefix("правил"))
            {
                sides.insert("right")
            }
            if token == "bilateral" || token.hasPrefix("двусторон") {
                sides.formUnion(["left", "right"])
            }
        }
        self.sides = sides

        negationCount = tokens.filter { token in
            ["no", "not", "without", "absent", "negative", "none", "не", "нет", "без"].contains(token)
                || token.hasPrefix("отсутств")
        }.count

        numbers = Set(Self.matches(#"(?<!\d)\d+(?:[.,]\d+)?(?!\d)"#, in: normalized)
            .compactMap(Self.number))

        var units = Set<DictationUnit>()
        for word in Self.matches(#"[\p{L}%]+"#, in: normalized) {
            if let unit = DictationUnit.fromWord(word) { units.insert(unit) }
        }
        self.units = units

        var measurements: [DictationUnit: Set<Double>] = [:]
        if let regex = try? NSRegularExpression(pattern: #"(?<!\d)(\d+(?:[.,]\d+)?)\s*([\p{L}%]+)"#) {
            for match in regex.matches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) {
                guard let numberRange = Range(match.range(at: 1), in: normalized),
                      let unitRange = Range(match.range(at: 2), in: normalized),
                      let number = Self.number(String(normalized[numberRange])),
                      let unit = DictationUnit.fromWord(String(normalized[unitRange]))
                else { continue }
                measurements[unit, default: []].insert(number)
            }
        }
        self.measurements = measurements

        hasUncertaintyCue = tokenList.contains {
            ["возможно", "вернее", "точнее", "поправка", "исправляю", "perhaps", "maybe", "possibly", "rather", "actually", "unsure", "uncertain"].contains($0)
        } || tokenList.indices.contains { index in
            index > 0 && tokenList[index - 1] == "не"
                && ["уверен", "уверена", "уверены"].contains(tokenList[index])
        }
    }

    func containsLiteral(_ value: DictationTextFacts) -> Bool {
        guard !value.tokens.isEmpty, value.tokens.count <= tokens.count else { return false }
        for start in 0 ... (tokens.count - value.tokens.count) {
            if Array(tokens[start ..< start + value.tokens.count]) == value.tokens { return true }
        }
        return false
    }

    private static func number(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }

    static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }
}

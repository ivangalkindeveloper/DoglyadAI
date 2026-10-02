enum DictationUnit: Hashable {
    case millimeter
    case centimeter
    case meter
    case gram
    case kilogram
    case milliliter
    case liter
    case percent

    static func fromWord(_ word: String) -> Self? {
        switch word {
        case "мм", "mm": return .millimeter
        case "см", "cm": return .centimeter
        case "м", "m": return .meter
        case "г", "g": return .gram
        case "кг", "kg": return .kilogram
        case "мл", "ml": return .milliliter
        case "л", "l": return .liter
        case "%": return .percent
        default:
            if word.hasPrefix("миллиметр") || word.hasPrefix("millimet") { return .millimeter }
            if word.hasPrefix("сантиметр") || word.hasPrefix("centimet") { return .centimeter }
            if word.hasPrefix("килограмм") || word.hasPrefix("kilogram") { return .kilogram }
            if word.hasPrefix("грамм") || word.hasPrefix("gram") { return .gram }
            if word.hasPrefix("метр") || word.hasPrefix("meter") { return .meter }
            if word.hasPrefix("миллилитр") || word.hasPrefix("millilit") { return .milliliter }
            if word.hasPrefix("литр") || word.hasPrefix("liter") { return .liter }
            if word.hasPrefix("процент") || word.hasPrefix("percent") { return .percent }
            return nil
        }
    }
}

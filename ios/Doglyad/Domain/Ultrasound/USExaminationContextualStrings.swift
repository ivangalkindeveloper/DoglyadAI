import Foundation

struct USExaminationContextualStrings: Codable, Equatable {
    let strings: [String: [String]]

    init(
        strings: [String: [String]]
    ) {
        self.strings = strings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        strings = try container.decode([String: [String]].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(strings)
    }

    /// Strings for the current locale, falling back to `en` and then to an empty array.
    func getStrings(for locale: Locale) -> [String] {
        let key = locale.language.languageCode?.identifier ?? "en"
        return strings[key] ?? strings["en"] ?? []
    }
}

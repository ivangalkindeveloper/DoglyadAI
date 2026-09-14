import Foundation

struct USExaminationReadyMadeTemplate: Codable, Identifiable, Equatable {
    let id: String
    let examinationType: String
    let title: [String: String]
    let content: [String: String]

    func getLocalizedTitle(for locale: Locale) -> LocalizedStringResource {
        LocalizedStringResource(stringLiteral: localizedValue(from: title, for: locale))
    }

    func getLocalizedContent(for locale: Locale) -> String {
        localizedValue(from: content, for: locale)
    }

    private func localizedValue(
        from values: [String: String],
        for locale: Locale
    ) -> String {
        let key = locale.language.languageCode?.identifier ?? "en"
        return values[key] ?? values["en"] ?? values.values.first ?? ""
    }
}

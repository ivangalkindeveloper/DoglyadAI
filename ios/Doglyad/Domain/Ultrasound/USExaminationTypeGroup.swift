import Foundation

struct USExaminationTypeGroup: Codable, Identifiable, Equatable {
    let id: String
    let title: [String: String]
    let examinationTypes: [USExaminationType]

    func getLocalizedTitle(for locale: Locale) -> LocalizedStringResource {
        let key = locale.language.languageCode?.identifier ?? "en"
        let localizedTitle = title[key] ?? title.values.first ?? ""
        return LocalizedStringResource(stringLiteral: localizedTitle)
    }
}

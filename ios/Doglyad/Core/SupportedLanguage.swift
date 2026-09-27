import Foundation

enum SupportedLanguage: String {
    case en
    case ru

    private static let defaultLanguage: SupportedLanguage = .en
    private static let current: SupportedLanguage = {
        guard let preferred = Bundle.main.preferredLocalizations.first,
              let code = Locale(identifier: preferred).language.languageCode?.identifier,
              let language = SupportedLanguage(rawValue: code)
        else {
            return defaultLanguage
        }
        return language
    }()

    static var currentCode: String { current.rawValue }
    static var currentLocale: Locale { Locale(identifier: currentCode) }
}

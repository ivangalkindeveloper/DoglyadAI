import Foundation

struct LocaleConfig: Codable {
    let defaultCode: String
    let codes: [String]
}

extension LocaleConfig {
    static let `default`: LocaleConfig = {
        let code = Locale.current.language.languageCode?.identifier ?? Locale.current.identifier
        return LocaleConfig(
            defaultCode: code,
            codes: [code],
        )
    }()
}

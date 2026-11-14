import Foundation

struct LocaleConfig: Codable {
    let defaultCode: String
    let codes: [String]

    init(
        defaultCode: String,
        codes: [String],
    ) {
        self.defaultCode = defaultCode
        self.codes = codes
    }
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

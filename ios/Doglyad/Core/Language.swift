import Foundation

struct Language {
    let currentCode: String
    let currentLocale: Locale

    init(
        localeConfig: LocaleConfig,
        preferredLanguageIdentifiers: [String],
    ) {
        let availableCodes = Set(
            localeConfig.codes,
        )
        let code = preferredLanguageIdentifiers
            .compactMap { Locale(
                identifier: $0,
            ).language.languageCode?.identifier }
            .first(
                where: availableCodes.contains,
            ) ?? localeConfig.defaultCode
        currentCode = code
        currentLocale = Locale(
            identifier: code,
        )
    }
}

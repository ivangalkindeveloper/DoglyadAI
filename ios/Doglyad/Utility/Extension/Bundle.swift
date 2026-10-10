import Foundation

extension Bundle {
    enum KeyString: String {
        case ENVIRONMENT
        case BASE_URL
        case REVENUECAT_API_KEY
        case CFBundleShortVersionString
        case CFBundleVersion
    }

    static func dictionaryString(
        _ key: KeyString,
    ) -> String {
        main.object(
            forInfoDictionaryKey: key.rawValue,
        ) as! String
    }

    static var shortVersion: Version {
        let parts = dictionaryString(
            .CFBundleShortVersionString,
        ).split(
            separator: ".",
        ).compactMap { Int(
            $0,
        ) }
        guard parts.count >= 3 else { return Version(
            major: 1,
            minor: 0,
            patch: 0,
        ) }
        return Version(
            major: parts[
                0,
            ],
            minor: parts[
                1,
            ],
            patch: parts[
                2,
            ],
        )
    }
}

import Foundation

enum AnalyticsDocument: String {
    case privacyPolicy = "privacy_policy"
    case termsAndConditions = "terms_and_conditions"
    case other

    init(url: URL) {
        if url.path.contains("privacy-policy") {
            self = .privacyPolicy
        } else if url.path.contains("terms-and-conditions") {
            self = .termsAndConditions
        } else {
            self = .other
        }
    }
}

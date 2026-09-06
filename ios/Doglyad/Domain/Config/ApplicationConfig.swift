import Foundation

struct ApplicationConfig: Codable {
    let isServiceAvailable: Bool
    let appStoreId: String
    let actualVersion: Version
    let contactEmail: String
    let appleUpdateUrl: URL
    /// The revision date of the current legal documents. When it is newer than the
    /// one the user accepted, the re-acceptance screen is shown.
    let legalDate: Date
    let privacyPolicyUrl: URL
    let termsAndConditionsUrl: URL
    let network: NetworkConfig
    let entitlements: [SubscriptionType: SubscriptionEntitlement]
    let ultrasound: UltrasoundConfig
    let history: HistoryConfig
}

extension ApplicationConfig {
    static let `default` = ApplicationConfig(
        isServiceAvailable: false,
        appStoreId: "",
        actualVersion: .default,
        contactEmail: "doglyadapp@gmail.com",
        appleUpdateUrl: URL(string: "https://apps.apple.com/app/id")!,
        legalDate: .distantPast,
        privacyPolicyUrl: URL(string: "https://ivangalkindeveloper.github.io/DoglyadAI/legal/privacy-policy")!,
        termsAndConditionsUrl: URL(string: "https://ivangalkindeveloper.github.io/DoglyadAI/legal/terms-and-conditions")!,
        network: .default,
        entitlements: [
            .base: SubscriptionEntitlement(
                requestCountPerDay: 10,
                formCompletionViaMicrophone: .unavailable,
                sendingConclusionByEmail: .unavailable,
                neuralModelSettings: .unavailable
            ),
        ],
        ultrasound: .default,
        history: .default
    )
}

extension ApplicationConfig {
    private enum CodingKeys: String, CodingKey {
        case isServiceAvailable
        case appStoreId
        case actualVersion
        case contactEmail
        case appleUpdateUrl
        case legalDate
        case privacyPolicyUrl
        case termsAndConditionsUrl
        case network
        case entitlements
        case ultrasound
        case history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isServiceAvailable = try container.decodeIfPresent(
            Bool.self,
            forKey: .isServiceAvailable
        ) ?? Self.default.isServiceAvailable
        appStoreId = try container.decode(String.self, forKey: .appStoreId)
        actualVersion = try container.decodeIfPresent(
            Version.self,
            forKey: .actualVersion
        ) ?? .default
        contactEmail = try container.decode(String.self, forKey: .contactEmail)
        appleUpdateUrl = try container.decode(URL.self, forKey: .appleUpdateUrl)
        legalDate = try container.decodeIfPresent(
            Date.self,
            forKey: .legalDate
        ) ?? Self.default.legalDate
        privacyPolicyUrl = try container.decode(URL.self, forKey: .privacyPolicyUrl)
        termsAndConditionsUrl = try container.decode(URL.self, forKey: .termsAndConditionsUrl)
        network = try container.decodeIfPresent(
            NetworkConfig.self,
            forKey: .network
        ) ?? .default
        ultrasound = try container.decodeIfPresent(
            UltrasoundConfig.self,
            forKey: .ultrasound
        ) ?? .default
        let rawEntitlements = try container.decode(
            [String: SubscriptionEntitlement].self,
            forKey: .entitlements
        )
        entitlements = Dictionary(
            uniqueKeysWithValues: rawEntitlements.compactMap { rawType, entitlement in
                SubscriptionType(rawValue: rawType).map { ($0, entitlement) }
            }
        )
        history = try container.decodeIfPresent(
            HistoryConfig.self,
            forKey: .history
        ) ?? .default
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isServiceAvailable, forKey: .isServiceAvailable)
        try container.encode(appStoreId, forKey: .appStoreId)
        try container.encode(actualVersion, forKey: .actualVersion)
        try container.encode(contactEmail, forKey: .contactEmail)
        try container.encode(appleUpdateUrl, forKey: .appleUpdateUrl)
        try container.encode(legalDate, forKey: .legalDate)
        try container.encode(privacyPolicyUrl, forKey: .privacyPolicyUrl)
        try container.encode(termsAndConditionsUrl, forKey: .termsAndConditionsUrl)
        try container.encode(network, forKey: .network)
        try container.encode(ultrasound, forKey: .ultrasound)
        try container.encode(history, forKey: .history)

        let rawEntitlements = Dictionary(
            uniqueKeysWithValues: entitlements.map { type, entitlement in
                (type.rawValue, entitlement)
            }
        )
        try container.encode(rawEntitlements, forKey: .entitlements)
    }
}

import Foundation

struct ApplicationConfig: Codable {
    let isServiceAvailable: Bool
    let appStoreId: String
    let locale: LocaleConfig
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
    let scan: ScanConfig
    let scanSpeech: ScanSpeechConfig
    let templateAdd: TemplateAddConfig
    let templateEdit: TemplateEditConfig
    let readyMadeTemplateList: ReadyMadeTemplateListConfig
    let workSettings: WorkSettingsConfig
    let settingsAI: SettingsAIConfig
}

extension ApplicationConfig {
    static let `default` = ApplicationConfig(
        isServiceAvailable: false,
        appStoreId: "",
        locale: .default,
        actualVersion: .default,
        contactEmail: "support@doglyad.ru",
        appleUpdateUrl: URL(
            string: "https://apps.apple.com/app/id",
        )!,
        legalDate: .distantPast,
        privacyPolicyUrl: URL(
            string: "https://ivangalkindeveloper.github.io/DoglyadAI/legal/privacy-policy",
        )!,
        termsAndConditionsUrl: URL(
            string: "https://ivangalkindeveloper.github.io/DoglyadAI/legal/terms-and-conditions",
        )!,
        network: .default,
        entitlements: [
            .base: SubscriptionEntitlement(
                requestCountPerDay: 10,
                formCompletionViaMicrophone: .unavailable,
                sendingReportByEmail: .unavailable,
                settingsAI: .unavailable,
            ),
        ],
        ultrasound: .default,
        history: .default,
        scan: .default,
        scanSpeech: .default,
        templateAdd: .default,
        templateEdit: .default,
        readyMadeTemplateList: .default,
        workSettings: .default,
        settingsAI: .default,
    )
}

extension ApplicationConfig {
    init(
        from decoder: Decoder,
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self,
        )
        isServiceAvailable = try container.decodeIfPresent(
            Bool.self,
            forKey: .isServiceAvailable,
        ) ?? Self.default.isServiceAvailable
        appStoreId = try container.decode(
            String.self,
            forKey: .appStoreId,
        )
        locale = try container.decode(
            LocaleConfig.self,
            forKey: .locale,
        )
        actualVersion = try container.decodeIfPresent(
            Version.self,
            forKey: .actualVersion,
        ) ?? .default
        contactEmail = try container.decode(
            String.self,
            forKey: .contactEmail,
        )
        appleUpdateUrl = try container.decode(
            URL.self,
            forKey: .appleUpdateUrl,
        )
        legalDate = try container.decodeIfPresent(
            Date.self,
            forKey: .legalDate,
        ) ?? Self.default.legalDate
        privacyPolicyUrl = try container.decode(
            URL.self,
            forKey: .privacyPolicyUrl,
        )
        termsAndConditionsUrl = try container.decode(
            URL.self,
            forKey: .termsAndConditionsUrl,
        )
        network = try container.decodeIfPresent(
            NetworkConfig.self,
            forKey: .network,
        ) ?? .default
        let ultrasound = try container.decodeIfPresent(
            UltrasoundConfig.self,
            forKey: .ultrasound,
        ) ?? .default
        let rawEntitlements = try container.decode(
            [String: SubscriptionEntitlement].self,
            forKey: .entitlements,
        )
        entitlements = Dictionary(
            uniqueKeysWithValues: rawEntitlements.compactMap { rawType, entitlement in
                SubscriptionType(
                    rawValue: rawType,
                ).map {
                    ($0, entitlement)
                }
            },
        )
        self.ultrasound = ultrasound
        history = try container.decodeIfPresent(
            HistoryConfig.self,
            forKey: .history,
        ) ?? .default
        scan = try container.decode(
            ScanConfig.self,
            forKey: .scan,
        )
        scanSpeech = try container.decode(
            ScanSpeechConfig.self,
            forKey: .scanSpeech,
        )
        templateAdd = try container.decode(
            TemplateAddConfig.self,
            forKey: .templateAdd,
        )
        templateEdit = try container.decode(
            TemplateEditConfig.self,
            forKey: .templateEdit,
        )
        readyMadeTemplateList = try container.decode(
            ReadyMadeTemplateListConfig.self,
            forKey: .readyMadeTemplateList,
        )
        workSettings = try container.decode(
            WorkSettingsConfig.self,
            forKey: .workSettings,
        )
        settingsAI = try container.decode(
            SettingsAIConfig.self,
            forKey: .settingsAI,
        )
        guard [
            scan.examinationNumberMaxLength,
            scan.patientNameMaxLength,
            scan.patientHeightCMMaxLength,
            scan.patientWeightKGMaxLength,
            scan.patientComplaintsMaxLength,
            scan.examinationDescriptionMaxLength,
            scanSpeech.transcriptMaxLength,
            templateAdd.nameMaxLength,
            templateAdd.contentMaxLength,
            templateEdit.nameMaxLength,
            templateEdit.contentMaxLength,
            readyMadeTemplateList.searchMaxLength,
            workSettings.emailMaxLength,
            settingsAI.temperatureMaxLength,
            settingsAI.maxTokensMaxLength,
        ].allSatisfy(
            {
                $0 > 0
            },
        ) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Module input limits must be positive",
                ),
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case isServiceAvailable
        case appStoreId
        case locale
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
        case scan
        case scanSpeech
        case templateAdd
        case templateEdit
        case readyMadeTemplateList
        case workSettings
        case settingsAI
    }

    func encode(
        to encoder: Encoder,
    ) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self,
        )
        try container.encode(
            isServiceAvailable,
            forKey: .isServiceAvailable,
        )
        try container.encode(
            appStoreId,
            forKey: .appStoreId,
        )
        try container.encode(
            locale,
            forKey: .locale,
        )
        try container.encode(
            actualVersion,
            forKey: .actualVersion,
        )
        try container.encode(
            contactEmail,
            forKey: .contactEmail,
        )
        try container.encode(
            appleUpdateUrl,
            forKey: .appleUpdateUrl,
        )
        try container.encode(
            legalDate,
            forKey: .legalDate,
        )
        try container.encode(
            privacyPolicyUrl,
            forKey: .privacyPolicyUrl,
        )
        try container.encode(
            termsAndConditionsUrl,
            forKey: .termsAndConditionsUrl,
        )
        try container.encode(
            network,
            forKey: .network,
        )
        try container.encode(
            ultrasound,
            forKey: .ultrasound,
        )
        try container.encode(
            history,
            forKey: .history,
        )
        try container.encode(
            scan,
            forKey: .scan,
        )
        try container.encode(
            scanSpeech,
            forKey: .scanSpeech,
        )
        try container.encode(
            templateAdd,
            forKey: .templateAdd,
        )
        try container.encode(
            templateEdit,
            forKey: .templateEdit,
        )
        try container.encode(
            readyMadeTemplateList,
            forKey: .readyMadeTemplateList,
        )
        try container.encode(
            workSettings,
            forKey: .workSettings,
        )
        try container.encode(
            settingsAI,
            forKey: .settingsAI,
        )

        let rawEntitlements = Dictionary(
            uniqueKeysWithValues: entitlements.map { type, entitlement in
                (type.rawValue, entitlement)
            },
        )
        try container.encode(
            rawEntitlements,
            forKey: .entitlements,
        )
    }
}

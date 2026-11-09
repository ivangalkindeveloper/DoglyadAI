#if DEBUG
    import Foundation

    enum WebDocumentPreviewDocument {
        case privacyPolicy
        case termsAndConditions

        var html: String {
            switch self {
            case .privacyPolicy: LegalDocumentPreviewHTML.privacyPolicy
            case .termsAndConditions: LegalDocumentPreviewHTML.termsAndConditions
            }
        }

        func arguments(
            container: DependencyContainer,
        ) -> WebDocumentArguments {
            switch self {
            case .privacyPolicy:
                WebDocumentArguments(
                    url: container.applicationConfig.privacyPolicyUrl,
                    title: container.l10n[
                        .privacyPolicyTitle,
                    ],
                )
            case .termsAndConditions:
                WebDocumentArguments(
                    url: container.applicationConfig.termsAndConditionsUrl,
                    title: container.l10n[
                        .termsAndConditionsTitle,
                    ],
                )
            }
        }
    }
#endif

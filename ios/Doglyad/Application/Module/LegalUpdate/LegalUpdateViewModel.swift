import DoglyadUI
import Foundation
import Router
import SwiftUI

@MainActor
final class LegalUpdateViewModel: DViewModel {
    override init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel
    ) {
        super.init(
            container: container,
            router: router,
            subscription: subscription
        )
    }

    @Published var isLegalAccepted: Bool = false

    var isAcceptDisabled: Bool {
        isLegalAccepted == false
    }

    func onTapPrivacyPolicy() {
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentBottomSheetArguments(
                url: container.applicationConfig.privacyPolicyUrl,
                title: .privacyPolicyTitle
            )
        )
    }

    func onTapTermsAndConditions() {
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentBottomSheetArguments(
                url: container.applicationConfig.termsAndConditionsUrl,
                title: .termsAndConditionsTitle
            )
        )
    }

    func onTapAccept() {
        container.sharedRepository.acceptLegal(
            documentDate: container.applicationConfig.legalDate
        )
        coordinator.root(
            .scan,
            animated: true
        )
    }
}

extension LegalUpdateViewModel {
    enum AttributedLinks: String {
        case privacy, terms
    }

    func legalAttributedText(theme: DTheme, locale: Locale) -> AttributedString {
        let typography: DTypography = theme.typography
        let color: DColor = theme.color

        var accept = AttributedString(localizedResource(.onBoardingLegalAcceptDescription, locale: locale))
        accept.font = typography.textSmall
        accept.foregroundColor = color.grayscaleHeader

        var privacy = AttributedString(localizedResource(.onBoardingPrivacyPolicyLabel, locale: locale))
        privacy.font = typography.textSmall
        privacy.foregroundColor = color.primaryDefault
        privacy.link = URL(string: AttributedLinks.privacy.rawValue)

        var and = AttributedString(localizedResource(.onBoardingLegalAcceptAndDescription, locale: locale))
        and.font = typography.textSmall
        and.foregroundColor = color.grayscaleHeader

        var terms = AttributedString(localizedResource(.onBoardingTermsAndConditionsLabel, locale: locale))
        terms.font = typography.textSmall
        terms.foregroundColor = color.primaryDefault
        terms.link = URL(string: AttributedLinks.terms.rawValue)

        return accept + privacy + and + terms
    }

    private func localizedResource(
        _ resource: LocalizedStringResource,
        locale: Locale
    ) -> String {
        var resource = resource
        resource.locale = locale
        return String(localized: resource)
    }

    func onLegalAttributedEnvironment(
        url: URL
    ) -> OpenURLAction.Result {
        switch url.absoluteString {
        case AttributedLinks.privacy.rawValue:
            onTapPrivacyPolicy()
            return .handled
        case AttributedLinks.terms.rawValue:
            onTapTermsAndConditions()
            return .handled
        default:
            return .systemAction
        }
    }
}

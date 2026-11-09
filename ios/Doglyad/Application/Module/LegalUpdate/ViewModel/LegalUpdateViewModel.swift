import Combine
import DoglyadUI
import Foundation
import Router
import SwiftUI

@MainActor
final class LegalUpdateViewModel: DModuleViewModel<any LegalUpdateStateProtocol> {
    @Published var isLegalAccepted = false
    private let messager: DMessager?

    init(
        container: DependencyContainer,
        messager: DMessager? = nil,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
    ) {
        self.messager = messager
        super.init(
            state: LegalUpdateAwaitingAcceptanceState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .legalUpdate,
            ),
        )
    }

    func legalAttributedText(
        theme: DTheme,
        locale: Locale,
    ) -> AttributedString {
        let typography: DTypography = theme.typography
        let color: DColor = theme.color

        var accept = AttributedString(
            localizedResource(
                container.l10n[
                    .onBoardingLegalAcceptDescription,
                ],
                locale: locale,
            ),
        )
        accept.font = typography.textSmall
        accept.foregroundColor = color.grayscaleHeader

        var privacy = AttributedString(
            localizedResource(
                container.l10n[
                    .onBoardingPrivacyPolicyLabel,
                ],
                locale: locale,
            ),
        )
        privacy.font = typography.textSmall
        privacy.foregroundColor = color.primaryDefault
        privacy.link = URL(
            string: AttributedLinks.privacy.rawValue,
        )

        var and = AttributedString(
            localizedResource(
                container.l10n[
                    .onBoardingLegalAcceptAndDescription,
                ],
                locale: locale,
            ),
        )
        and.font = typography.textSmall
        and.foregroundColor = color.grayscaleHeader

        var terms = AttributedString(
            localizedResource(
                container.l10n[
                    .onBoardingTermsAndConditionsLabel,
                ],
                locale: locale,
            ),
        )
        terms.font = typography.textSmall
        terms.foregroundColor = color.primaryDefault
        terms.link = URL(
            string: AttributedLinks.terms.rawValue,
        )

        return accept + privacy + and + terms
    }

    func onLegalAcceptedChanged(
        _ isAccepted: Bool,
    ) {
        analytics.buttonTapped(
            .legalUpdateLegalToggle,
            parameters: AnalyticsParameters(
                [
                    .result: .bool(
                        isAccepted,
                    ),
                ],
            ),
        )
        withAnimation(
            DTheme.light.animation,
        ) {
            isLegalAccepted = isAccepted
        }
    }

    func onLegalAttributedEnvironment(
        url: URL,
    ) -> OpenURLAction.Result {
        switch AttributedLinks(
            rawValue: url.absoluteString,
        ) {
        case .privacy:
            onTapPrivacyPolicy()
            return .handled
        case .terms:
            onTapTermsAndConditions()
            return .handled
        case .none:
            return .systemAction
        }
    }

    func onTapPrivacyPolicy() {
        analytics.buttonTapped(
            .legalUpdatePrivacyPolicy,
        )
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentArguments(
                url: container.applicationConfig.privacyPolicyUrl,
                title: container.l10n[
                    .privacyPolicyTitle,
                ],
            ),
        )
    }
}

extension LegalUpdateViewModel {
    enum AttributedLinks: String {
        case privacy, terms
    }

    func onTapTermsAndConditions() {
        analytics.buttonTapped(
            .legalUpdateTermsAndConditions,
        )
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentArguments(
                url: container.applicationConfig.termsAndConditionsUrl,
                title: container.l10n[
                    .termsAndConditionsTitle,
                ],
            ),
        )
    }

    func onTapAccept() {
        guard isLegalAccepted else {
            return
        }

        analytics.buttonTapped(
            .legalUpdateAccept,
        )
        performLocalOperation {
            try await self.container.sharedRepository.acceptLegal(
                documentDate: self.container.applicationConfig.legalDate,
            )
        } onSuccess: { _ in
            self.coordinator.root(
                .scan,
                isAnimated: true,
            )
        } onFailure: { error in
            self.emit(
                LegalUpdateErrorState(
                    error: error,
                ),
            )
            self.messager?.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}

private extension LegalUpdateViewModel {
    func localizedResource(
        _ resource: LocalizedStringResource,
        locale: Locale,
    ) -> String {
        var resource = resource
        resource.locale = locale
        return String(
            localized: resource,
        )
    }
}

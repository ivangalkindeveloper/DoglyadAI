import Combine
import DoglyadUI
import Foundation
import Router
import SwiftUI

@MainActor
final class OnBoardingViewModel: DModuleViewModel<any OnBoardingStateProtocol> {
    private let messager: DMessager?

    init(
        container: DependencyContainer,
        messager: DMessager? = nil,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        self.messager = messager
        super.init(
            state: OnBoardingFirstState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .onBoarding,
            ),
        )
    }

    func onLegalAcceptedChanged(
        _ isAccepted: Bool,
    ) {
        analytics.buttonTapped(
            .onboardingLegalToggle,
            parameters: AnalyticsParameters(
                [
                    .result: .bool(
                        isAccepted,
                    ),
                ],
            ),
        )
        switch state {
        case _ as OnBoardingLegalState:
            emit(
                OnBoardingLegalState(
                    isLegalAccepted: isAccepted,
                ),
            )
        default: break
        }
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
            .onboardingPrivacyPolicy,
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

    func onTapTermsAndConditions() {
        analytics.buttonTapped(
            .onboardingTermsAndConditions,
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

    func onPressedBack() {
        analytics.buttonTapped(
            .onboardingBack,
            parameters: .onboardingPage(
                index: state.index,
            ),
        )
        switch state {
        case _ as OnBoardingFirstState, _ as OnBoardingCompletingState: break
        case _ as OnBoardingSecondState: emit(
                OnBoardingFirstState(),
            )
        case _ as OnBoardingLegalState: emit(
                OnBoardingSecondState(),
            )
        case _ as OnBoardingExaminationTypeState: emit(
                OnBoardingLegalState(),
            )
        case _ as OnBoardingFinalState, _ as OnBoardingFailedState: emit(
                OnBoardingExaminationTypeState(),
            )
        default: preconditionFailure(
                "Unexpected onboarding state",
            )
        }
    }
}

extension OnBoardingViewModel {
    enum AttributedLinks: String {
        case privacy, terms
    }

    func onPressedNext() {
        analytics.buttonTapped(
            .onboardingPrimary,
            parameters: .onboardingPage(
                index: state.index,
            ),
        )
        switch state {
        case _ as OnBoardingFirstState: emit(
                OnBoardingSecondState(),
            )
        case _ as OnBoardingSecondState: emit(
                OnBoardingLegalState(),
            )
        case let state as OnBoardingLegalState:
            guard state.isLegalAccepted else { return }
            emit(
                OnBoardingExaminationTypeState(),
            )
        case _ as OnBoardingExaminationTypeState:
            coordinator.sheet(
                .selectUSExaminationType,
                arguments: SelectUSExaminationTypeArguments(
                    onSelected: { [weak self] type in
                        guard let self else { return }
                        try await container.ultrasoundReportRepository.setSelectedExaminationTypeId(
                            id: type.id,
                        )
                        emit(
                            OnBoardingFinalState(),
                        )
                    },
                ),
            )
        case _ as OnBoardingFinalState, _ as OnBoardingFailedState:
            completeOnBoarding()
        case _ as OnBoardingCompletingState: break
        default: preconditionFailure(
                "Unexpected onboarding state",
            )
        }
    }
}

private extension OnBoardingViewModel {
    func completeOnBoarding() {
        emit(
            OnBoardingCompletingState(),
        )
        handle {
            try await self.container.sharedRepository.acceptLegal(
                documentDate: self.container.applicationConfig.legalDate,
            )
            try await self.container.sharedRepository.setOnBoardingCompleted(
                isCompleted: true,
            )
            try await self.coordinator.navigateAfterOnBoarding()
        } onMainUnknownError: { error in
            self.emit(
                OnBoardingFailedState(
                    error: error,
                ),
            )
            self.messager?.showUnknownError(
                l10n: self.l10n,
            )
        }
    }

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

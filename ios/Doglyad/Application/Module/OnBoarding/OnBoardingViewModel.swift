import Combine
import DoglyadUI
import Foundation
import Router
import SwiftUI

@MainActor
final class OnBoardingViewModel: DModuleViewModel {
    private let messager: DMessager?
    enum Page: CaseIterable {
        case first, second, third, fourth, fifth

        var index: Int {
            Self.allCases.firstIndex(
                of: self,
            ) ?? 0
        }
    }

    init(
        container: DependencyContainer,
        messager: DMessager? = nil,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        self.messager = messager
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .onBoarding,
            ),
        )
    }

    @Published var page: Page = .first
    @Published var isLegalAccepted: Bool = false

    var isLegalDisabled: Bool {
        switch page {
        case .third:
            isLegalAccepted == false
        case .first, .second, .fourth, .fifth:
            false
        }
    }

    var isBackButtonVisible: Bool {
        switch page {
        case .first:
            false
        case .second, .third, .fourth, .fifth:
            true
        }
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
        isLegalAccepted = isAccepted
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
                index: page.index,
            ),
        )
        switch page {
        case .first:
            break
        case .second:
            move(
                to: .first,
            )
        case .third:
            move(
                to: .second,
            )
        case .fourth:
            move(
                to: .third,
            )
        case .fifth:
            move(
                to: .fourth,
            )
        }
    }
}

extension OnBoardingViewModel {
    enum AttributedLinks: String {
        case privacy, terms
    }

    func buttonTitle(
        _ page: OnBoardingViewModel.Page,
    ) -> LocalizedStringResource {
        switch page {
        case .first, .second:
            container.l10n[
                .buttonNext,
            ]
        case .third:
            container.l10n[
                .buttonAccept,
            ]
        case .fourth:
            container.l10n[
                .buttonSelectType,
            ]
        case .fifth:
            container.l10n[
                .buttonStart,
            ]
        }
    }

    func onPressedNext() {
        analytics.buttonTapped(
            .onboardingPrimary,
            parameters: .onboardingPage(
                index: page.index,
            ),
        )
        switch page {
        case .first:
            move(
                to: .second,
            )
        case .second:
            move(
                to: .third,
            )
        case .third:
            move(
                to: .fourth,
            )
        case .fourth:
            coordinator.sheet(
                .selectUSExaminationType,
                arguments: SelectUSExaminationTypeArguments(
                    onSelected: { [weak self] type in
                        guard let self else { return }

                        try await container.ultrasoundReportRepository.setSelectedExaminationTypeId(
                            id: type.id,
                        )
                        move(
                            to: .fifth,
                        )
                    },
                ),
            )
        case .fifth:
            handle {
                try await self.container.sharedRepository.acceptLegal(
                    documentDate: self.container.applicationConfig.legalDate,
                )
                try await self.container.sharedRepository.setOnBoardingCompleted(
                    isCompleted: true,
                )
                try await self.coordinator.navigateAfterOnBoarding()
            } onMainUnknownError: { _ in
                self.messager?.showUnknownError(
                    l10n: self.container.l10n,
                )
            }
        }
    }
}

private extension OnBoardingViewModel {
    func move(
        to page: Page,
    ) {
        switch page {
        case .third:
            isLegalAccepted = false
        case .first, .second, .fourth, .fifth:
            break
        }
        self.page = page
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

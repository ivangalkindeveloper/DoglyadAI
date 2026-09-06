import DoglyadUI
import Foundation
import Router
import SwiftUI

@MainActor
final class OnBoardingViewModel: DViewModel {
    enum Page: CaseIterable {
        case first, second, third, fourth, fifth

        var index: Int {
            Self.allCases.firstIndex(of: self) ?? 0
        }
    }

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel
    ) {
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.onBoarding)
        )
    }

    @Published var page: Page = .first
    @Published var isLegalAccepted: Bool = false

    var isLegalDisabled: Bool {
        page == .third && isLegalAccepted == false
    }

    func onLegalAcceptedChanged(
        _ value: Bool
    ) {
        analytics.buttonTapped(
            .onboardingLegalToggle,
            parameters: AnalyticsParameters([
                .result: .bool(value),
            ])
        )
        isLegalAccepted = value
    }

    func onTapPrivacyPolicy() {
        analytics.buttonTapped(.onboardingPrivacyPolicy)
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentBottomSheetArguments(
                url: container.applicationConfig.privacyPolicyUrl,
                title: .privacyPolicyTitle
            )
        )
    }

    func onTapTermsAndConditions() {
        analytics.buttonTapped(.onboardingTermsAndConditions)
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentBottomSheetArguments(
                url: container.applicationConfig.termsAndConditionsUrl,
                title: .termsAndConditionsTitle
            )
        )
    }

    func buttonTitle(
        _ page: OnBoardingViewModel.Page
    ) -> LocalizedStringResource {
        switch page {
        case .first, .second:
            .buttonNext
        case .third:
            .buttonAccept
        case .fourth:
            .buttonSelectType
        case .fifth:
            .buttonStart
        }
    }

    func onPressedNext() {
        analytics.buttonTapped(
            .onboardingPrimary,
            parameters: AnalyticsParameters([
                .source: .string(String(page.index + 1)),
            ])
        )
        switch page {
        case .first:
            page = .second
        case .second:
            page = .third
        case .third:
            page = .fourth
        case .fourth:
            coordinator.sheet(
                .selectUSExaminationType,
                arguments: SelectUSExaminationTypeArguments(
                    onSelected: { [weak self] type in
                        guard let self = self else { return }

                        self.page = .fifth
                        self.container.ultrasoundConclusionRepository.setSelectedExaminationTypeId(
                            id: type.id
                        )
                    }
                )
            )
        case .fifth:
            container.sharedRepository.setOnBoardingCompleted(
                value: true
            )
            // Record which revision of the documents the user accepted.
            container.sharedRepository.acceptLegal(
                documentDate: container.applicationConfig.legalDate
            )
            handle {
                try await self.coordinator.navigateAfterOnBoarding()
            }
        }
    }
}

extension OnBoardingViewModel {
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

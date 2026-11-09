import Combine
import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class SettingsViewModel: DModuleViewModel<any SettingsStateProtocol> {
    @Published var reportsCount: Int?

    init(
        messager _: DMessager,
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
    ) {
        super.init(
            state: SettingsContentState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .settings,
            ),
        )
    }

    var historyDescription: LocalizedStringResource {
        guard let reportsCount else {
            return l10n[
                .settingsHistoryPurposeDescription,
            ]
        }
        return reportsCount == 0 ? l10n[
            .settingsHistoryEmptyDescription,
        ] : l10n.resource(
            .settingsHistoryDescription,
            values: [.count: String(
                reportsCount,
            )],
        )
    }

    override func onInit() {
        handle {
            try await self.container.ultrasoundReportRepository.getReportsCount()
        } onMainSuccess: { count in
            guard !Task.isCancelled else {
                return
            }
            self.reportsCount = count
        } onMainUnknownError: { _ in
            // The summary is optional; all Settings destinations remain available.
        }
    }

    func onTapBack() {
        analytics.buttonTapped(
            .settingsBack,
        )
        coordinator.pop()
    }

    func onTapHistory() {
        analytics.buttonTapped(
            .settingsHistory,
            parameters: AnalyticsParameters(
                [
                    .itemCount: .int(
                        reportsCount ?? 0,
                    ),
                ],
            ),
        )
        coordinator.screen(
            .history,
        )
    }

    func onTapTemplates() {
        analytics.buttonTapped(
            .settingsTemplates,
        )
        coordinator.screen(
            .templateList,
        )
    }

    func onTapUserSettings() {
        analytics.buttonTapped(
            .settingsUserSettings,
        )
        coordinator.screen(
            .userSettings,
        )
    }

    func onTapSettingsAI() {
        analytics.buttonTapped(
            .settingsSettingsAI,
        )
        coordinator.screen(
            .settingsAI,
        )
    }

    func onTapSubscription() {
        analytics.buttonTapped(
            .settingsSubscription,
            parameters: .subscription(
                type: subscriptionStatus?.type,
            ),
        )
        coordinator.screen(
            .manageSubscription,
        )
    }

    func onTapStorage() {
        analytics.buttonTapped(
            .settingsStorage,
        )
        coordinator.screen(
            .storage,
        )
    }

    func onTapPrivacyPolicy() {
        analytics.buttonTapped(
            .settingsPrivacyPolicy,
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
            .settingsTermsAndConditions,
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

    func onTapAboutApp() {
        analytics.buttonTapped(
            .settingsAbout,
        )
        coordinator.sheet(
            .about,
        )
    }
}

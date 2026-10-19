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
    @Published var reportsCount = 0

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        super.init(
            state: SettingsLoadingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .settings,
            ),
        )
    }

    var historyDescription: LocalizedStringResource {
        reportsCount == 0 ? l10n[
            .settingsHistoryEmptyDescription,
        ] : l10n.resource(
            .settingsHistoryDescription,
            values: ["count": String(
                reportsCount,
            )],
        )
    }

    override func onInit() {
        emit(
            SettingsLoadingState(),
        )
        handle {
            try await self.container.ultrasoundReportRepository.getReportsCount()
        } onMainSuccess: { count in
            self.reportsCount = count
            self.emit(
                SettingsContentState(),
            )
        } onMainUnknownError: { error in
            self.emit(
                SettingsFailedState(
                    error: error,
                ),
            )
        }
    }

    func onTapRetry() { onInit() }

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
                        reportsCount,
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
            .subscription,
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

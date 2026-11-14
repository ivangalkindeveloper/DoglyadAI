import Combine
import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class MenuViewModel: DModuleViewModel<any MenuStateProtocol> {
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
            state: MenuContentState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .menu,
            ),
        )
    }

    var historyDescription: LocalizedStringResource {
        guard let reportsCount else {
            return l10n[
                .menuHistoryPurposeDescription,
            ]
        }
        return reportsCount == 0 ? l10n[
            .menuHistoryEmptyDescription,
        ] : l10n.resource(
            .menuHistoryDescription,
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
            .menuBack,
        )
        coordinator.pop()
    }

    func onTapHistory() {
        analytics.buttonTapped(
            .menuHistory,
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
            .menuTemplates,
        )
        coordinator.screen(
            .templateList,
        )
    }

    func onTapWorkSettings() {
        analytics.buttonTapped(
            .menuWorkSettings,
        )
        coordinator.screen(
            .workSettings,
        )
    }

    func onTapSettingsAI() {
        analytics.buttonTapped(
            .menuSettingsAI,
        )
        coordinator.screen(
            .settingsAI,
        )
    }

    func onTapSubscription() {
        analytics.buttonTapped(
            .menuSubscription,
            parameters: .subscription(
                type: subscriptionStatus?.type,
            ),
        )
        coordinator.screen(
            .subscriptionManage,
        )
    }

    func onTapStorage() {
        analytics.buttonTapped(
            .menuStorage,
        )
        coordinator.screen(
            .storage,
        )
    }

    func onTapPrivacyPolicy() {
        analytics.buttonTapped(
            .menuPrivacyPolicy,
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
            .menuTermsAndConditions,
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
            .menuAbout,
        )
        coordinator.sheet(
            .about,
        )
    }
}

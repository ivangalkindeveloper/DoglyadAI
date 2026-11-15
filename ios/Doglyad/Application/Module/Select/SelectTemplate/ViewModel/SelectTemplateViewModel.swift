import Combine
import DoglyadUI
import Foundation

@MainActor
final class SelectTemplateViewModel: DModuleViewModel<any SelectTemplateStateProtocol> {
    private let messager: DMessager?
    private let arguments: SelectTemplateArguments

    init(
        container: DependencyContainer,
        messager: DMessager? = nil,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        arguments: SelectTemplateArguments,
    ) {
        self.messager = messager
        self.arguments = arguments
        super.init(
            state: SelectTemplateContentState(
                templates: arguments.templates,
                currentTemplateID: arguments.currentValue?.id,
            ),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .bottomSheet(
                .selectTemplate,
            ),
            analyticsParameters: AnalyticsParameters(
                [
                    .hasCurrentValue: .bool(
                        arguments.currentValue != nil,
                    ),
                ],
            ),
        )
    }

    func onTemplateTap(
        _ template: USExaminationTemplate,
    ) {
        analytics.buttonTapped(
            .selectTemplate,
        )
        performLocalOperation {
            try await self.arguments.onSelected(
                template,
            )
        }
        onSuccess: { _ in
            self.emit(
                self.state.copyWith(
                    templates: nil,
                    currentTemplateID: .some(
                        template.id,
                    ),
                ),
            )
            self.coordinator.dismissSheet()
        } onFailure: { _ in
            self.messager?.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}

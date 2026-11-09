import Combine
import DoglyadUI
import Foundation

@MainActor
final class SelectTemplateViewModel: DModuleViewModel<any SelectTemplateStateProtocol> {
    @Published private(set) var templates: [USExaminationTemplate] = []
    @Published private(set) var currentTemplateID: UUID?
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
        templates = arguments.templates
        currentTemplateID = arguments.currentValue?.id
        self.messager = messager
        self.arguments = arguments
        super.init(
            state: SelectTemplateContentState(),
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

    #if DEBUG
        func setPreviewTemplates(
            _ templates: [USExaminationTemplate],
        ) {
            self.templates = templates
        }
    #endif

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
            self.currentTemplateID = template.id
            self.emit(
                SelectTemplateContentState(),
            )
            self.coordinator.dismissSheet()
        } onFailure: { _ in
            self.emit(
                SelectTemplateContentState(),
            )
            self.messager?.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}

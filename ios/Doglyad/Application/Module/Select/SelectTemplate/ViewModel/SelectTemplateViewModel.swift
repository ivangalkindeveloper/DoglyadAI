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
        onRequestCountIncremented: @escaping () -> Void,
        arguments: SelectTemplateArguments,
    ) {
        self.messager = messager
        self.arguments = arguments
        currentTemplateID = arguments.currentValue?.id
        super.init(
            state: SelectTemplateLoadingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
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

    override func onInit() {
        let usExaminationId = arguments.usExaminationId
        handle {
            let templates = try await self.container.templateRepository.getTemplates(
                usExaminationTypesById: self.container.usExaminationTypesById,
            )
            guard let usExaminationId else { return templates }
            return templates.filter { $0.usExaminationType.id == usExaminationId }
        } onMainSuccess: { templates in
            self.templates = templates
            self.emit(
                templates.isEmpty ? SelectTemplateEmptyState() : SelectTemplateContentState(),
            )
        } onMainUnknownError: { error in
            self.emit(
                SelectTemplateFailedState(
                    error: error,
                ),
            )
            self.messager?.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    func onTapRetry() { onInit() }

    func onTemplateTap(
        _ template: USExaminationTemplate,
    ) {
        analytics.buttonTapped(
            .selectTemplate,
        )
        switch state { case _ as SelectTemplateContentState: break
        default: return }
        emit(
            SelectTemplateLoadingState(),
        )
        handle { try await self.arguments.onSelected(
            template,
        ) }
        onMainSuccess: { _ in
            self.currentTemplateID = template.id
            self.emit(
                SelectTemplateContentState(),
            )
            self.coordinator.dismissSheet()
        } onMainUnknownError: { _ in
            self.emit(
                SelectTemplateContentState(),
            )
            self.messager?.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}

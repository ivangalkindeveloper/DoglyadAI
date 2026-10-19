import Combine
import DoglyadNetwork
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class TemplateListViewModel: DModuleViewModel<any TemplateListStateProtocol> {
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
            state: TemplateListLoadingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .templateList,
            ),
        )
    }

    override func onInit() {
        loadTemplates()
    }

    func onTapRetry() { loadTemplates() }

    func onTapBack() {
        analytics.buttonTapped(
            .templateListBack,
        )
        coordinator.pop()
    }

    func onTapAdd() {
        analytics.buttonTapped(
            .templateListAdd,
        )
        coordinator.screen(
            .templateAdd,
            arguments: TemplateAddArguments(
                onTemplatesChanged: { [weak self] in
                    self?.loadTemplates()
                },
            ),
        )
    }

    func onTapTemplate(
        _ template: USExaminationTemplate,
    ) {
        analytics.buttonTapped(
            .templateListTemplate,
        )
        coordinator.screen(
            .templateEdit,
            arguments: TemplateEditArguments(
                templateId: template.id,
                onTemplatesChanged: { [weak self] in
                    self?.loadTemplates()
                },
            ),
        )
    }
}

private extension TemplateListViewModel {
    func loadTemplates() {
        emit(
            TemplateListLoadingState(),
        )
        handle {
            try await self.container.templateRepository.getTemplates(
                usExaminationTypesById: self.container.usExaminationTypesById,
            )
        } onMainSuccess: { templates in
            self.emit(
                templates.isEmpty ? TemplateListEmptyState() : TemplateListContentState(
                    templates: templates,
                ),
            )
        } onMainUnknownError: { error in
            self.emit(
                TemplateListFailedState(
                    error: error,
                ),
            )
        }
    }
}

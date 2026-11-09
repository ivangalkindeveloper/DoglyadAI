import Combine
import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class TemplateListViewModel: DModuleViewModel<any TemplateListStateProtocol> {
    private let messager: DMessager

    init(
        messager: DMessager,
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
    ) {
        self.messager = messager
        super.init(
            state: TemplateListInitialState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .templateList,
            ),
        )
    }

    override func onInit() {
        loadTemplates()
    }

    func onTapRetry() {
        loadTemplates()
    }

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

    private func loadTemplates() {
        cancelOperationTask()
        performLocalOperation {
            try await self.container.templateRepository.getTemplates(
                usExaminationTypesById: self.container.usExaminationTypesById,
            )
        } onSuccess: { templates in
            self.emit(
                templates.isEmpty ? TemplateListEmptyState() : TemplateListContentState(
                    templates: templates,
                ),
            )
        } onFailure: { error in
            switch self.state {
            case _ as TemplateListContentState: break
            default:
                self.emit(
                    TemplateListErrorState(
                        error: error,
                    ),
                )
            }
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }
}

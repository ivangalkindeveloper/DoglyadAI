import Combine
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class ReadyMadeTemplateListViewModel: DModuleViewModel<any ReadyMadeTemplateListStateProtocol> {
    @Published var focus: ReadyMadeTemplateListFocus?

    @NestedObservableObject var controller = DTextFieldController()

    private let arguments: ReadyMadeTemplateListArguments

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: ReadyMadeTemplateListArguments,
    ) {
        self.arguments = arguments

        super.init(
            state: ReadyMadeTemplateListLoadingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .readyMadeTemplateList,
            ),
        )
    }

    var query: String? {
        guard let value = controller.value?
            .trimmingCharacters(
                in: .whitespacesAndNewlines,
            ),
            !value.isEmpty
        else {
            return nil
        }
        return value
    }

    var filteredTemplates: [USExaminationReadyMadeTemplate] {
        let templates: [USExaminationReadyMadeTemplate]
        switch state { case let state as ReadyMadeTemplateListContentState: templates = state.templates
        default: return [] }
        guard let query else { return templates }

        return templates.filter { template in
            let values = [
                localizedExaminationTypeTitle(
                    for: template,
                ),
                String(
                    localized: template.localizedTitle,
                ),
                template.content,
            ]
            return values.contains { value in
                value.localizedCaseInsensitiveContains(
                    query,
                )
            }
        }
    }

    var emptyDescription: LocalizedStringResource {
        query == nil
            ? l10n[
                .readyMadeTemplateListEmptyDescription,
            ]
            : l10n[
                .readyMadeTemplateListSearchEmptyDescription,
            ]
    }

    private var typesById: [String: USExaminationType] { container.usExaminationTypesById }

    override func onInit() {
        loadTemplates()
    }

    func onTapBack() {
        analytics.buttonTapped(
            .readyMadeTemplateListBack,
        )
        coordinator.pop()
    }

    func onTapRetry() {
        analytics.buttonTapped(
            .readyMadeTemplateListRetry,
        )
        loadTemplates()
    }

    func onFocusChanged(
        _ newFocus: ReadyMadeTemplateListFocus?,
    ) {
        focus = newFocus
    }

    func unfocus() {
        focus = nil
    }

    func onTapTemplate(
        _ template: USExaminationReadyMadeTemplate,
    ) {
        analytics.buttonTapped(
            .readyMadeTemplateListTemplate,
        )
        coordinator.pop()
        arguments.onTemplateSelected(
            template,
        )
    }

    private func loadTemplates() {
        emit(
            ReadyMadeTemplateListLoadingState(),
        )
        handle {
            try await self.container.templateRepository.getReadyMadeTemplates(
                languageCode: self.container.language.currentCode,
            )
        } onMainSuccess: { templates in
            self.emit(
                ReadyMadeTemplateListContentState(
                    templates: templates,
                ),
            )
        } onMainApiError: { error in
            self.emit(
                ReadyMadeTemplateListFailedState(
                    error: error,
                ),
            )
        } onMainConnectionError: { error in
            self.emit(
                ReadyMadeTemplateListFailedState(
                    error: error,
                ),
            )
        } onMainUnknownError: { error in
            self.emit(
                ReadyMadeTemplateListFailedState(
                    error: error,
                ),
            )
        }
    }

    private func localizedExaminationTypeTitle(
        for template: USExaminationReadyMadeTemplate,
    ) -> String {
        guard let type = typesById[
            template.examinationType,
        ] else {
            return template.examinationType
        }
        return String(
            localized: type.localizedTitle,
        )
    }

    func examinationTypeTitle(
        for template: USExaminationReadyMadeTemplate,
    ) -> LocalizedStringResource {
        LocalizedStringResource(
            stringLiteral: localizedExaminationTypeTitle(
                for: template,
            ),
        )
    }
}

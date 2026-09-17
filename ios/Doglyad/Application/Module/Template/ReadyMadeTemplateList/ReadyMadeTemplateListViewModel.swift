import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class ReadyMadeTemplateListViewModel: DViewModel {
    enum Focus: Hashable {
        case search
    }

    enum State: Equatable {
        case loading
        case error
        case success([USExaminationReadyMadeTemplate])
    }

    private let arguments: ReadyMadeTemplateListScreenArguments

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: ReadyMadeTemplateListScreenArguments
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.readyMadeTemplateList)
        )
    }

    @Published var focus: Focus?
    @Published private(set) var state: State = .loading
    @NestedObservableObject var searchController = DTextFieldController()

    var filteredTemplates: [USExaminationReadyMadeTemplate] {
        guard case let .success(templates) = state else { return [] }
        guard let query = searchQuery else { return templates }

        return templates.filter { template in
            let values = [
                localizedExaminationTypeTitle(for: template),
                String(localized: template.getLocalizedTitle(for: Locale.current)),
                template.getLocalizedContent(for: Locale.current),
            ]
            return values.contains { value in
                value.localizedCaseInsensitiveContains(query)
            }
        }
    }

    var emptyDescription: LocalizedStringResource {
        searchQuery == nil
            ? .readyMadeTemplateListEmptyDescription
            : .readyMadeTemplateListSearchEmptyDescription
    }

    override func onInit() {
        loadTemplates()
    }

    func onTapBack() {
        analytics.buttonTapped(.readyMadeTemplateListBack)
        coordinator.pop()
    }

    func onTapRetry() {
        analytics.buttonTapped(.readyMadeTemplateListRetry)
        loadTemplates()
    }

    func unfocus() {
        focus = nil
    }

    func onTapTemplate(_ template: USExaminationReadyMadeTemplate) {
        analytics.buttonTapped(.readyMadeTemplateListTemplate)
        coordinator.pop()
        arguments.onTemplateSelected(template)
    }

    func examinationTypeTitle(
        for template: USExaminationReadyMadeTemplate
    ) -> LocalizedStringResource {
        LocalizedStringResource(
            stringLiteral: localizedExaminationTypeTitle(for: template)
        )
    }

    private var searchQuery: String? {
        guard let value = searchController.value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            return nil
        }
        return value
    }

    private func localizedExaminationTypeTitle(
        for template: USExaminationReadyMadeTemplate
    ) -> String {
        guard let type = container.getUSExaminationTypeById(id: template.examinationType) else {
            return template.examinationType
        }
        return String(localized: type.getLocalizedTitle(for: Locale.current))
    }

    private func loadTemplates() {
        state = .loading
        handle {
            try await self.container.templateRepository.getReadyMadeTemplates()
        } onMainSuccess: { templates in
            self.state = .success(templates)
        } onMainApiError: { _ in
            self.state = .error
        } onMainConnectionError: { _ in
            self.state = .error
        } onMainUnknownError: { _ in
            self.state = .error
        }
    }
}

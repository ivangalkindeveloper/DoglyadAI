import Combine
import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class TemplateEditViewModel: DModuleViewModel, DTextFieldFocusValidating {
    enum Focus: Hashable {
        case name
        case content
    }

    private let messager: DMessager
    private let arguments: TemplateEditArguments
    private let onSaveTemplate: (USExaminationTemplate) async throws -> Void
    private let onDeleteTemplate: (UUID) async throws -> Void

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        messager: DMessager,
        arguments: TemplateEditArguments,
        onSaveTemplate: @escaping (USExaminationTemplate) async throws -> Void,
        onDeleteTemplate: @escaping (UUID) async throws -> Void,
    ) {
        self.messager = messager
        self.arguments = arguments
        self.onSaveTemplate = onSaveTemplate
        self.onDeleteTemplate = onDeleteTemplate
        usExaminationType = container.usExaminationTypeDefault
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .templateEdit,
            ),
        )
    }

    override func onInit() {
        handle {
            try await self.container.templateRepository.getTemplate(
                id: self.arguments.templateId,
                usExaminationTypesById: self.container.usExaminationTypesById,
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { template in
            guard let template else {
                self.messager.showUnknownError(
                    l10n: self.container.l10n,
                )
                return
            }
            self.usExaminationType = self.container.usExaminationTypesById[
                template.usExaminationType.id,
            ]
                ?? self.container.usExaminationTypeDefault
            self.nameController.setText(
                template.name,
            )
            self.templateController.setText(
                template.content,
            )
        } onMainUnknownError: { _ in
            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    @Published private(set) var isLoading = true
    @Published var focus: Focus?
    @Published var usExaminationType: USExaminationType
    @NestedObservableObject var nameController = DTextFieldController(
        isRequired: true,
    )
    @NestedObservableObject var templateController = DTextFieldController(
        isRequired: true,
    )

    var focusList: [DTextFieldFocusValidationItem<Focus>] {
        [
            DTextFieldFocusValidationItem(
                focus: .name,
                controller: nameController,
            ),
            DTextFieldFocusValidationItem(
                focus: .content,
                controller: templateController,
            ),
        ]
    }

    func onTapBack() {
        analytics.buttonTapped(
            .templateEditBack,
        )
        coordinator.pop()
    }

    func onFocusChanged(
        _ newFocus: Focus?,
    ) {
        focus = newFocus
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        analytics.buttonTapped(
            .templateEditSubmit,
        )
        switch focus {
        case .name:
            focus = .content
        case .content, .none:
            focus = nil
        }
    }

    var isPreviousFieldFocusable: Bool {
        switch focus {
        case .name, .none:
            false
        case .content:
            true
        }
    }

    var isNextFieldFocusable: Bool {
        switch focus {
        case .name:
            true
        case .content, .none:
            false
        }
    }

    func onTapToolbarUp() {
        switch focus {
        case .name, .none:
            break
        case .content:
            focus = .name
        }
    }

    func onTapToolbarDown() {
        switch focus {
        case .name:
            focus = .content
        case .content, .none:
            break
        }
    }

    func onTapExaminationType() {
        analytics.buttonTapped(
            .templateEditExaminationType,
        )
        coordinator.sheet(
            .selectUSExaminationType,
            arguments: SelectUSExaminationTypeArguments(
                currentValue: usExaminationType,
                onSelected: { [weak self] type in
                    self?.usExaminationType = type
                },
            ),
        )
    }

    func onTapSave() {
        guard !isLoading else { return }

        analytics.buttonTapped(
            .templateEditSave,
        )
        if let invalidFocus = firstInvalidFocus() {
            focus = invalidFocus
            return
        }

        guard let name = nameController.value,
              let content = templateController.value
        else {
            return
        }

        unfocus()

        let template = USExaminationTemplate(
            id: arguments.templateId,
            usExaminationType: usExaminationType,
            name: name,
            content: content,
        )
        isLoading = true
        handle {
            try await self.onSaveTemplate(
                template,
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { _ in
            self.messager.show(
                type: .success,
                title: self.container.l10n[
                    .templateSavedSuccessTitle,
                ],
                description: self.container.l10n[
                    .templateSavedSuccessDescription,
                ],
            )
            self.coordinator.pop()
        } onMainUnknownError: { _ in
            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    func onTapDelete() {
        guard !isLoading else { return }

        analytics.buttonTapped(
            .templateEditDelete,
        )
        coordinator.sheet(
            .templateDelete,
            arguments: TemplateDeleteArguments(
                onConfirm: { [weak self] in
                    self?.deleteTemplate()
                },
            ),
        )
    }

    private func deleteTemplate() {
        guard !isLoading else { return }
        isLoading = true
        unfocus()

        handle {
            try await self.onDeleteTemplate(
                self.arguments.templateId,
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { _ in
            self.messager.show(
                type: .success,
                title: self.container.l10n[
                    .templateDeletedSuccessTitle,
                ],
                description: self.container.l10n[
                    .templateDeletedSuccessDescription,
                ],
            )
            self.coordinator.pop()
        } onMainUnknownError: { _ in
            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}

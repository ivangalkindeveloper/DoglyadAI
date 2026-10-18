import Combine
import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class TemplateAddViewModel: DModuleViewModel<any TemplateAddStateProtocol>, DTextFieldFocusValidatingProtocol {
    @Published var focus: TemplateAddFocus?

    @Published var usExaminationType: USExaminationType

    @NestedObservableObject var nameController = DTextFieldController(
        isRequired: true,
    )

    @NestedObservableObject var templateController = DTextFieldController(
        isRequired: true,
    )

    let templateId = UUID()

    private let messager: DMessager
    private let onSaveTemplate: (USExaminationTemplate) async throws -> Void

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        messager: DMessager,
        onSaveTemplate: @escaping (USExaminationTemplate) async throws -> Void,
    ) {
        self.messager = messager
        self.onSaveTemplate = onSaveTemplate

        usExaminationType = container.usExaminationTypeDefault

        super.init(
            state: TemplateAddLoadingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .templateAdd,
            ),
        )
        _ = nameController
        _ = templateController
    }

    var focusList: [DTextFieldFocusValidationItem<TemplateAddFocus>] {
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

    override func onInit() {
        handle {
            try await self.container.ultrasoundReportRepository.getSelectedExaminationTypeId()
        } onDefer: { switch self.state {
        case _ as TemplateAddLoadingState: self.emit(
                TemplateAddDefaultState(),
            )
        default: break
        } } onMainSuccess: { id in
            if let id, let type = self.container.usExaminationTypesById[
                id,
            ] { self.usExaminationType = type }
        } onMainUnknownError: { error in
            self.emit(
                TemplateAddFailedState(
                    error: error,
                ),
            )
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }

    func onTapBack() {
        analytics.buttonTapped(
            .templateAddBack,
        )
        coordinator.pop()
    }

    func onFocusChanged(
        _ newFocus: TemplateAddFocus?,
    ) {
        focus = newFocus
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        analytics.buttonTapped(
            .templateAddSubmit,
        )
        switch focus {
        case .name:
            focus = .content
        case .content, .none:
            focus = nil
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
            .templateAddExaminationType,
        )
        coordinator.sheet(
            .selectUSExaminationType,
            arguments: SelectUSExaminationTypeArguments(
                currentValue: usExaminationType,
                onSelected: { [weak self] type in
                    withAnimation(
                        DTheme.light.animation,
                    ) {
                        self?.usExaminationType = type
                    }
                },
            ),
        )
    }

    func onTapReadyMadeTemplates() {
        analytics.buttonTapped(
            .templateAddReadyMadeTemplates,
        )
        unfocus()
        coordinator.screen(
            .readyMadeTemplateList,
            arguments: ReadyMadeTemplateListArguments(
                onTemplateSelected: { [weak self] template in
                    self?.onReadyMadeTemplateSelected(
                        template,
                    )
                },
            ),
        )
    }

    func onTapSave() {
        switch state {
        case _ as TemplateAddLoadingState: return
        default: break
        }

        analytics.buttonTapped(
            .templateAddSave,
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
            id: templateId,
            usExaminationType: usExaminationType,
            name: name,
            content: content,
        )
        emit(
            TemplateAddLoadingState(),
        )
        handle {
            try await self.onSaveTemplate(
                template,
            )
        } onDefer: {
            switch self.state {
            case _ as TemplateAddLoadingState: self.emit(
                    TemplateAddDefaultState(),
                )
            default: break
            }
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
        } onMainUnknownError: { error in
            self.emit(
                TemplateAddFailedState(
                    error: error,
                ),
            )

            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    private func onReadyMadeTemplateSelected(
        _ template: USExaminationReadyMadeTemplate,
    ) {
        guard let examinationType = container.getUSExaminationTypeById(
            id: template.examinationType,
        ) else { return }

        usExaminationType = examinationType
        nameController.setText(
            String(
                localized: template.localizedTitle,
            ),
        )
        templateController.setText(
            template.content,
        )
    }
}

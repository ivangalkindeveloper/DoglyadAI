import Combine
import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class TemplateEditViewModel: DModuleViewModel<any TemplateEditStateProtocol>, DTextFieldFocusValidatingProtocol {
    @Published var focus: TemplateEditFocus?

    @Published var usExaminationType: USExaminationType

    @NestedObservableObject var nameTextController = DTextFieldController(
        isRequired: true,
    )

    @NestedObservableObject var templateTextController = DTextFieldController(
        isRequired: true,
    )

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
            state: TemplateEditLoadingState(),
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
        _ = nameTextController
        _ = templateTextController
    }

    var focusList: [DTextFieldFocusValidationItem<TemplateEditFocus>] {
        [
            DTextFieldFocusValidationItem(
                focus: .name,
                inputTextController: nameTextController,
            ),
            DTextFieldFocusValidationItem(
                focus: .content,
                inputTextController: templateTextController,
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
        emit(
            TemplateEditLoadingState(),
        )
        handle {
            try await self.container.templateRepository.getTemplate(
                id: self.arguments.templateId,
                usExaminationTypesById: self.container.usExaminationTypesById,
            )
        } onDefer: {
            switch self.state {
            case _ as TemplateEditLoadingState: self.emit(
                    TemplateEditDefaultState(),
                )
            default: break
            }
        } onMainSuccess: { template in
            guard let template else {
                self.emit(
                    TemplateEditInitializationFailedState(
                        error: CocoaError(
                            .fileReadNoSuchFile,
                        ),
                    ),
                )
                self.messager.showUnknownError(
                    l10n: self.container.l10n,
                )
                return
            }
            self.usExaminationType = self.container.usExaminationTypesById[
                template.usExaminationType.id,
            ]
                ?? self.container.usExaminationTypeDefault
            self.nameTextController.setText(
                template.name,
            )
            self.templateTextController.setText(
                template.content,
            )
        } onMainUnknownError: { error in
            self.emit(
                TemplateEditInitializationFailedState(
                    error: error,
                ),
            )

            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    func onTapRetryInitialization() { onInit() }

    func onTapBack() {
        analytics.buttonTapped(
            .templateEditBack,
        )
        coordinator.pop()
    }

    func onFocusChanged(
        _ newFocus: TemplateEditFocus?,
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
                    withAnimation(
                        DTheme.light.animation,
                    ) {
                        self?.usExaminationType = type
                    }
                },
            ),
        )
    }

    func onTapSave() {
        switch state {
        case _ as TemplateEditLoadingState, _ as TemplateEditInitializationFailedState: return
        default: break
        }

        analytics.buttonTapped(
            .templateEditSave,
        )
        if let invalidFocus = firstInvalidFocus() {
            focus = invalidFocus
            return
        }

        guard let name = nameTextController.value,
              let content = templateTextController.value
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
        emit(
            TemplateEditLoadingState(),
        )
        handle {
            try await self.onSaveTemplate(
                template,
            )
        } onDefer: {
            switch self.state {
            case _ as TemplateEditLoadingState: self.emit(
                    TemplateEditDefaultState(),
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
                TemplateEditFailedState(
                    error: error,
                ),
            )

            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    func onTapDelete() {
        switch state {
        case _ as TemplateEditLoadingState, _ as TemplateEditInitializationFailedState: return
        default: break
        }

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
        switch state {
        case _ as TemplateEditLoadingState, _ as TemplateEditInitializationFailedState: return
        default: break
        }
        emit(
            TemplateEditLoadingState(),
        )
        unfocus()

        handle {
            try await self.onDeleteTemplate(
                self.arguments.templateId,
            )
        } onDefer: {
            switch self.state {
            case _ as TemplateEditLoadingState: self.emit(
                    TemplateEditDefaultState(),
                )
            default: break
            }
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
        } onMainUnknownError: { error in
            self.emit(
                TemplateEditFailedState(
                    error: error,
                ),
            )

            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}

import Combine
import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class WorkSettingsViewModel: DModuleViewModel<any WorkSettingsStateProtocol>, DTextFieldFocusValidatingProtocol {
    @Published var focus: WorkSettingsFocus?
    @Published var isNeedPatientConsent: Bool
    @Published var isRecommendationsIncluded: Bool
    @Published var isPhotoRemarks: Bool
    @Published var isDescriptionRemarks: Bool
    @NestedObservableObject var emailTextController: DTextFieldController
    private let messager: DMessager
    private let onSaved: (String?, Bool, Bool, Bool, Bool) async throws -> Void

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        getInitialEmail: @escaping () -> String?,
        getInitialIsNeedPatientConsent: @escaping () -> Bool,
        getInitialIsRecommendationsIncluded: @escaping () -> Bool,
        getInitialIsPhotoRemarks: @escaping () -> Bool,
        getInitialIsDescriptionRemarks: @escaping () -> Bool,
        onSaved: @escaping (String?, Bool, Bool, Bool, Bool) async throws -> Void,
    ) {
        isNeedPatientConsent = getInitialIsNeedPatientConsent()
        isRecommendationsIncluded = getInitialIsRecommendationsIncluded()
        isPhotoRemarks = getInitialIsPhotoRemarks()
        isDescriptionRemarks = getInitialIsDescriptionRemarks()

        _emailTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldEmailFormatter(),
                    DTextFieldMaxLengthFormatter(
                        maxLength: container.applicationConfig.workSettings.emailMaxLength,
                    ),
                ],
                validators: [
                    DTextFieldEmailValidator(
                        invalidValueErrorText: String(
                            localized: container.l10n[
                                .errorInvalidEmailDescription,
                            ],
                        ),
                    ),
                    DTextFieldLengthValidator(
                        validRange: 0 ... container.applicationConfig.workSettings.emailMaxLength,
                        invalidValueErrorText: container.l10n.text(
                            .errorFieldLengthExceededDescription,
                            values: [.maxLength: String(
                                container.applicationConfig.workSettings.emailMaxLength,
                            )],
                        ),
                    ),
                ],
            ),
        )
        self.messager = messager
        self.onSaved = onSaved

        super.init(
            state: WorkSettingsInitialState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .workSettings,
            ),
        )
        _ = emailTextController
        emailTextController.restoreText(
            getInitialEmail() ?? "",
        )
    }

    var focusList: [DTextFieldFocusValidationItem<WorkSettingsFocus>] {
        [
            DTextFieldFocusValidationItem(
                focus: .email,
                inputTextController: emailTextController,
            ),
        ]
    }

    func onTapBack() {
        analytics.buttonTapped(
            .workSettingsBack,
        )
        coordinator.pop()
    }

    func onFocusChanged(
        _ newFocus: WorkSettingsFocus?,
    ) {
        focus = newFocus
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        analytics.buttonTapped(
            .workSettingsSubmit,
        )
        switch focus {
        case .email, .none:
            focus = nil
        }
    }

    func togglePatientConsent() {
        isNeedPatientConsent.toggle()
    }

    func toggleRecommendationsIncluded() {
        isRecommendationsIncluded.toggle()
    }

    func togglePhotoRemarks() {
        isPhotoRemarks.toggle()
    }

    func toggleDescriptionRemarks() {
        isDescriptionRemarks.toggle()
    }

    func onTapSave() {
        let email = emailTextController.value
        analytics.buttonTapped(
            .workSettingsSave,
            parameters: AnalyticsParameters(
                [
                    .hasCurrentValue: .bool(
                        email != nil,
                    ),
                ],
            ),
        )
        if let invalidFocus = firstInvalidFocus() {
            focus = invalidFocus
            return
        }

        unfocus()

        let isNeedPatientConsent = isNeedPatientConsent
        let isRecommendationsIncluded = isRecommendationsIncluded
        let isPhotoRemarks = isPhotoRemarks
        let isDescriptionRemarks = isDescriptionRemarks
        performLocalOperation {
            try await self.onSaved(
                email,
                isNeedPatientConsent,
                isRecommendationsIncluded,
                isPhotoRemarks,
                isDescriptionRemarks,
            )
        } onSuccess: { _ in
            self.messager.show(
                type: .success,
                title: self.container.l10n[
                    .workSettingsSavedSuccessMessageTitle,
                ],
                description: self.container.l10n[
                    .workSettingsSavedSuccessMessageDescription,
                ],
            )
            if self.emailTextController.value == email,
               self.isNeedPatientConsent == isNeedPatientConsent,
               self.isRecommendationsIncluded == isRecommendationsIncluded,
               self.isPhotoRemarks == isPhotoRemarks,
               self.isDescriptionRemarks == isDescriptionRemarks
            {
                self.coordinator.pop()
            }
        } onFailure: { error in
            self.emit(
                WorkSettingsErrorState(
                    error: error,
                ),
            )

            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}

import Combine
import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class UserSettingsViewModel: DModuleViewModel<any UserSettingsStateProtocol>, DTextFieldFocusValidatingProtocol {
    @Published var focus: UserSettingsFocus?

    @Published var isRecommendationsIncluded: Bool

    @Published var isPhotoRemarks: Bool

    @Published var isDescriptionRemarks: Bool

    @NestedObservableObject var emailTextController: DTextFieldController

    private let messager: DMessager
    private let onSaved: (String?, Bool, Bool, Bool) async throws -> Void

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        getInitialEmail: @escaping () -> String?,
        getInitialIsRecommendationsIncluded: @escaping () -> Bool,
        getInitialIsPhotoRemarks: @escaping () -> Bool,
        getInitialIsDescriptionRemarks: @escaping () -> Bool,
        onSaved: @escaping (String?, Bool, Bool, Bool) async throws -> Void,
    ) {
        self.messager = messager
        self.onSaved = onSaved

        isRecommendationsIncluded = getInitialIsRecommendationsIncluded()
        isPhotoRemarks = getInitialIsPhotoRemarks()
        isDescriptionRemarks = getInitialIsDescriptionRemarks()
        _emailTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldEmailFormatter(),
                    DTextFieldMaxLengthFormatter(
                        maxLength: 254,
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
                ],
            ),
        )

        super.init(
            state: UserSettingsDefaultState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .userSettings,
            ),
        )
        _ = emailTextController
        emailTextController.setText(
            getInitialEmail() ?? "",
        )
    }

    var focusList: [DTextFieldFocusValidationItem<UserSettingsFocus>] {
        [
            DTextFieldFocusValidationItem(
                focus: .email,
                inputTextController: emailTextController,
            ),
        ]
    }

    func onTapBack() {
        analytics.buttonTapped(
            .userSettingsBack,
        )
        coordinator.pop()
    }

    func onFocusChanged(
        _ newFocus: UserSettingsFocus?,
    ) {
        focus = newFocus
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        analytics.buttonTapped(
            .userSettingsSubmit,
        )
        switch focus {
        case .email, .none:
            focus = nil
        }
    }

    func toggleRecommendationsIncluded() {
        isRecommendationsIncluded.toggle()
    }

    func togglePhotoRemarks() { isPhotoRemarks.toggle() }

    func toggleDescriptionRemarks() { isDescriptionRemarks.toggle() }

    func onTapSave() {
        switch state {
        case _ as UserSettingsLoadingState: return
        default: break
        }

        let email = emailTextController.value
        analytics.buttonTapped(
            .userSettingsSave,
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

        emit(
            UserSettingsLoadingState(),
        )
        handle {
            try await self.onSaved(
                email,
                self.isRecommendationsIncluded,
                self.isPhotoRemarks,
                self.isDescriptionRemarks,
            )
        } onDefer: {
            switch self.state {
            case _ as UserSettingsLoadingState: self.emit(
                    UserSettingsDefaultState(),
                )
            default: break
            }
        } onMainSuccess: { _ in
            self.messager.show(
                type: .success,
                title: self.container.l10n[
                    .userSettingsSavedSuccessMessageTitle,
                ],
                description: self.container.l10n[
                    .userSettingsSavedSuccessMessageDescription,
                ],
            )
            self.coordinator.pop()
        } onMainUnknownError: { error in
            self.emit(
                UserSettingsFailedState(
                    error: error,
                ),
            )

            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}

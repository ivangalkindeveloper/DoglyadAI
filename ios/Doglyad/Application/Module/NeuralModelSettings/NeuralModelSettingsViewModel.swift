import Combine
import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class NeuralModelSettingsViewModel: DModuleViewModel, DTextFieldFocusValidating {
    enum Focus: Hashable {
        case temperature
        case length
    }

    private let messager: DMessager
    private let onSettingsSaved: (Bool, Double?, Int?) -> Void

    init(
        container: DependencyContainer,
        getInitialIsMarkdown: @escaping () -> Bool,
        getInitialTemperature: @escaping () -> Double,
        getInitialMaxTokens: @escaping () -> Int,
        messager: DMessager,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        onSettingsSaved: @escaping (Bool, Double?, Int?) -> Void,
    ) {
        self.messager = messager
        self.onSettingsSaved = onSettingsSaved
        _temperatureController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldDecimalFormatter(),
                ],
                validators: [
                    DTextFieldDoubleRangeValidator(
                        validRange: 0 ... 2,
                        invalidValueErrorText: String(
                            localized: container.l10n[
                                .errorInvalidNeuralModelTemperatureDescription,
                            ],
                        ),
                    ),
                ],
            ),
        )
        _maxTokensController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldIntegerFormatter(),
                ],
                validators: [
                    DTextFieldIntRangeValidator(
                        validRange: 1 ... 4096,
                        invalidValueErrorText: String(
                            localized: container.l10n[
                                .errorInvalidNeuralModelMaxTokensDescription,
                            ],
                        ),
                    ),
                ],
            ),
        )
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .neuralModelSettings,
            ),
        )
        isMarkdown = getInitialIsMarkdown()
        temperatureController.setText(
            String(
                getInitialTemperature(),
            ),
        )
        maxTokensController.setText(
            String(
                getInitialMaxTokens(),
            ),
        )
    }

    @Published private(set) var isLoading = false
    @Published var focus: Focus?
    @Published var isMarkdown: Bool = false
    @NestedObservableObject var temperatureController: DTextFieldController
    @NestedObservableObject var maxTokensController: DTextFieldController

    var focusList: [DTextFieldFocusValidationItem<Focus>] {
        [
            DTextFieldFocusValidationItem(
                focus: .temperature,
                controller: temperatureController,
            ),
            DTextFieldFocusValidationItem(
                focus: .length,
                controller: maxTokensController,
            ),
        ]
    }

    func unfocus() {
        focus = nil
    }

    var canFocusPreviousField: Bool {
        switch focus {
        case .temperature, .none:
            false
        case .length:
            true
        }
    }

    var canFocusNextField: Bool {
        switch focus {
        case .temperature:
            true
        case .length, .none:
            false
        }
    }

    func onTapToolbarUp() {
        switch focus {
        case .temperature, .none:
            break
        case .length:
            focus = .temperature
        }
    }

    func onTapToolbarDown() {
        switch focus {
        case .temperature:
            focus = .length
        case .length, .none:
            break
        }
    }

    func toggleIsMarkdown() {
        analytics.buttonTapped(
            .neuralModelSettingsMarkdown,
            parameters: AnalyticsParameters(
                [
                    .result: .bool(
                        !isMarkdown,
                    ),
                ],
            ),
        )
        isMarkdown.toggle()
    }

    func onSubmit() {
        analytics.buttonTapped(
            .neuralModelSettingsSubmit,
        )
        switch focus {
        case .temperature:
            focus = .length
        case .length, .none:
            focus = nil
        }
    }

    func onTapBack() {
        analytics.buttonTapped(
            .neuralModelSettingsBack,
        )
        coordinator.pop()
    }

    func onTapSave() {
        guard !isLoading else { return }

        analytics.buttonTapped(
            .neuralModelSettingsSave,
            parameters: AnalyticsParameters(
                [
                    .result: .bool(
                        isMarkdown,
                    ),
                ],
            ),
        )

        if let invalidFocus = firstInvalidFocus() {
            focus = invalidFocus
            return
        }

        unfocus()
        isLoading = true

        onSettingsSaved(
            isMarkdown,
            temperatureController.value.flatMap { Double(
                $0,
            ) },
            maxTokensController.value.flatMap { Int(
                $0,
            ) },
        )
        messager.show(
            type: .success,
            title: container.l10n[
                .neuralModelSettingsSavedSuccessMessageTitle,
            ],
            description: container.l10n[
                .neuralModelSettingsSavedSuccessMessageDescription,
            ],
        )
        coordinator.pop()
    }
}

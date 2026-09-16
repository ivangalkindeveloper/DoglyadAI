import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class NeuralModelSettingsViewModel: DViewModel, DTextFieldFocusValidating {
    enum Focus: Hashable {
        case temperature
        case length
    }

    private let messager: DMessager
    private let onSettingsSaved: (Bool, Double?, Int?) -> Void

    init(
        container: DependencyContainer,
        initialIsMarkdown: Bool,
        initialTemperature: Double,
        initialMaxTokens: Int,
        messager: DMessager,
        router: DRouter,
        subscription: SubscriptionViewModel,
        onSettingsSaved: @escaping (Bool, Double?, Int?) -> Void
    ) {
        self.messager = messager
        self.onSettingsSaved = onSettingsSaved
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.neuralModelSettings)
        )
        isMarkdown = initialIsMarkdown
        temperatureController.setText(String(initialTemperature))
        maxTokensController.setText(String(initialMaxTokens))
    }

    @Published var focus: Focus?
    @Published var isMarkdown: Bool = false
    @NestedObservableObject var temperatureController = DTextFieldController(
        formatters: [
            DTextFieldDecimalFormatter(),
        ],
        validators: [
            DTextFieldDoubleRangeValidator(
                validRange: 0 ... 2,
                invalidValueErrorText: String(localized: .errorInvalidNeuralModelTemperature)
            ),
        ]
    )
    @NestedObservableObject var maxTokensController = DTextFieldController(
        formatters: [
            DTextFieldIntegerFormatter(),
        ],
        validators: [
            DTextFieldIntRangeValidator(
                validRange: 1 ... 1024,
                invalidValueErrorText: String(localized: .errorInvalidNeuralModelMaxTokens)
            ),
        ]
    )

    var focusList: [DTextFieldFocusValidationItem<Focus>] {
        [
            DTextFieldFocusValidationItem(
                focus: .temperature,
                controller: temperatureController
            ),
            DTextFieldFocusValidationItem(
                focus: .length,
                controller: maxTokensController
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
            parameters: AnalyticsParameters([
                .result: .bool(!isMarkdown),
            ])
        )
        isMarkdown.toggle()
    }

    func onSubmit() {
        analytics.buttonTapped(.neuralModelSettingsSubmit)
        switch focus {
        case .temperature:
            focus = .length
        case .length, .none:
            focus = nil
        }
    }

    func onTapBack() {
        analytics.buttonTapped(.neuralModelSettingsBack)
        coordinator.pop()
    }

    func onTapSave() {
        analytics.buttonTapped(
            .neuralModelSettingsSave,
            parameters: AnalyticsParameters([
                .result: .bool(isMarkdown),
            ])
        )

        if let invalidFocus = firstInvalidFocus() {
            focus = invalidFocus
            return
        }

        onSettingsSaved(
            isMarkdown,
            temperatureController.value.flatMap { Double($0) },
            maxTokensController.value.flatMap { Int($0) }
        )
        messager.show(
            type: .success,
            title: .neuralModelSettingsSavedSuccessMessageTitle,
            description: .neuralModelSettingsSavedSuccessMessageDescription
        )
        coordinator.pop()
    }
}

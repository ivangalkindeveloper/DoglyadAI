import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class NeuralModelSettingsViewModel: DViewModel {
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
        temperatureController.text = String(initialTemperature)
        maxTokensController.text = String(initialMaxTokens)
    }

    @Published var focus: Focus?
    @Published var isMarkdown: Bool = false
    @NestedObservableObject var temperatureController = DTextFieldController()
    @NestedObservableObject var maxTokensController = DTextFieldController()

    func unfocus() {
        focus = nil
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
        onSettingsSaved(
            isMarkdown,
            Double(temperatureController.text),
            Int(maxTokensController.text)
        )
        messager.show(
            type: .success,
            title: .neuralModelSettingsSavedSuccessMessageTitle,
            description: .neuralModelSettingsSavedSuccessMessageDescription
        )
        coordinator.pop()
    }
}

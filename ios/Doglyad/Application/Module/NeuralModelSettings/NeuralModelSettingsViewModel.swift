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
            subscription: subscription
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
        isMarkdown.toggle()
    }

    func onSubmit() {
        switch focus {
        case .temperature:
            focus = .length
        case .length, .none:
            focus = nil
        }
    }

    func onTapBack() {
        coordinator.pop()
    }

    func onTapSave() {
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

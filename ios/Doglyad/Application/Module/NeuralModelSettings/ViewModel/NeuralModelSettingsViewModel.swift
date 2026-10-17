import Combine
import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class NeuralModelSettingsViewModel: DModuleViewModel<any NeuralModelSettingsStateProtocol>, DTextFieldFocusValidatingProtocol {
    @Published var focus: NeuralModelSettingsFocus?
    @Published var isMarkdown: Bool = false
    @NestedObservableObject var temperatureController: DTextFieldController
    @NestedObservableObject var maxTokensController: DTextFieldController
    var focusList: [DTextFieldFocusValidationItem<NeuralModelSettingsFocus>] {
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

    var isPreviousFieldFocusable: Bool {
        switch focus {
        case .temperature, .none:
            false
        case .length:
            true
        }
    }

    var isNextFieldFocusable: Bool {
        switch focus {
        case .temperature:
            true
        case .length, .none:
            false
        }
    }

    private let messager: DMessager
    private let onSettingsSaved: (Bool, Double?, Int?) async throws -> Void

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
        onSettingsSaved: @escaping (Bool, Double?, Int?) async throws -> Void,
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
            state: NeuralModelSettingsDefaultState(),
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
        _ = temperatureController
        _ = maxTokensController
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

    func onFocusChanged(
        _ newFocus: NeuralModelSettingsFocus?,
    ) {
        focus = newFocus
    }

    func unfocus() {
        focus = nil
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
        switch state {
        case _ as NeuralModelSettingsLoadingState: return
        default: break
        }

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
        emit(
            NeuralModelSettingsLoadingState(),
        )

        handle {
            try await self.onSettingsSaved(
                self.isMarkdown,
                self.temperatureController.value.flatMap { Double(
                    $0,
                ) },
                self.maxTokensController.value.flatMap { Int(
                    $0,
                ) },
            )
        } onDefer: {
            switch self.state {
            case _ as NeuralModelSettingsLoadingState: self.emit(
                    NeuralModelSettingsDefaultState(),
                )
            default: break
            }
        } onMainSuccess: { _ in
            self.messager.show(
                type: .success,
                title: self.container.l10n[
                    .neuralModelSettingsSavedSuccessMessageTitle,
                ],
                description: self.container.l10n[
                    .neuralModelSettingsSavedSuccessMessageDescription,
                ],
            )
            self.coordinator.pop()
        } onMainUnknownError: { error in
            self.emit(
                NeuralModelSettingsFailedState(
                    error: error,
                ),
            )

            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}

import Combine
import DoglyadUI
import Foundation
import NestedObservableObject
import Router

@MainActor
final class SelectNeuralModelViewModel: DModuleViewModel<any SelectNeuralModelStateProtocol> {
    let models: [USExaminationNeuralModel]

    @Published var currentValue: USExaminationNeuralModel?

    private let messager: DMessager?
    private let arguments: SelectNeuralModelArguments?

    init(
        container: DependencyContainer,
        messager: DMessager? = nil,
        router: DRouter,
        arguments: SelectNeuralModelArguments?,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        self.messager = messager
        self.arguments = arguments

        models = (container.usExaminationNeuralModels)
        currentValue = (arguments?.currentValue)

        super.init(
            state: SelectNeuralModelContentState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .selectNeuralModel,
            ),
            analyticsParameters: .neuralModelSelection(
                currentModelId: arguments?.currentValue?.id,
            ),
        )
    }

    func isSelected(
        _ model: USExaminationNeuralModel,
    ) -> Bool {
        currentValue == model
    }

    func isProBadgeVisible(
        for model: USExaminationNeuralModel,
    ) -> Bool {
        switch model.entitlement {
        case .base:
            false
        case .pro:
            switch subscriptionStatus?.type {
            case .some(
                .pro,
            ):
                false
            case .some(
                .base,
            ), .none:
                true
            }
        }
    }

    func isComingSoonBadgeVisible(
        for model: USExaminationNeuralModel,
    ) -> Bool {
        switch model.accessibility {
        case .available, .unavailable:
            false
        case .comingSoon:
            true
        }
    }

    func isSelectionEnabled(
        for model: USExaminationNeuralModel,
    ) -> Bool {
        switch model.accessibility {
        case .available:
            true
        case .comingSoon, .unavailable:
            false
        }
    }

    func onModelTap(
        _ model: USExaminationNeuralModel,
    ) {
        analytics.buttonTapped(
            .selectNeuralModel,
            parameters: AnalyticsParameters(
                [
                    .modelId: .string(
                        model.id,
                    ),
                ],
            ),
        )
        switch state {
        case _ as SelectNeuralModelSelectingState: return
        default: break
        }

        emit(
            SelectNeuralModelSelectingState(),
        )
        handle {
            try await self.coordinator.selectNeuralModel(
                model,
            ) { [weak self] model in
                try await self?.arguments?.onSelected(
                    model,
                )
                self?.currentValue = model
            }
        } onDefer: {
            self.emit(
                SelectNeuralModelContentState(),
            )
        } onMainUnknownError: { _ in
            self.messager?.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}

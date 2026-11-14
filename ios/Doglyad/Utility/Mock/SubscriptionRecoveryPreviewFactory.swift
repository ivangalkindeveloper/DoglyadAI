#if DEBUG
    import Combine
    import DoglyadUI
    import Foundation

    @MainActor
    enum SubscriptionRecoveryPreviewFactory {
        static func makeViewModel(
            container: DependencyContainer,
            router: DRouter,
            isFailure: Bool = false,
            state: (any SubscriptionRecoveryStateProtocol)? = nil,
            input: String = "",
            onRecover: ((String) -> Void)? = nil,
            messager: DMessager? = nil,
        ) -> SubscriptionRecoveryViewModel {
            let model = SubscriptionRecoveryViewModel(
                messager: messager ?? DMessager(),
                container: container,
                router: router,
                getSubscriptionStatus: {
                    nil
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                arguments: nil,
                recover: { key in
                    if isFailure {
                        throw URLError(
                            .notConnectedToInternet,
                        )
                    }
                    onRecover?(
                        key,
                    )
                    return SubscriptionManagePreviewFactory.makeStatus(
                        source: .robokassa,
                    )
                },
            )
            model.recoveryTextController.setText(
                input,
            )
            if let state {
                model.preparePreview(
                    state: state,
                )
            }
            return model
        }
    }
#endif

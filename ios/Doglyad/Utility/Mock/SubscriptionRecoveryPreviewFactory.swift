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
            onRecover: ((String) -> Void)? = nil,
        ) -> SubscriptionRecoveryViewModel {
            let model = SubscriptionRecoveryViewModel(
                messager: DMessager(),
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
                createRecoveryKey: {
                    if isFailure {
                        throw URLError(
                            .notConnectedToInternet,
                        )
                    }
                    return "Preview-MixedCase-Recovery-Key"
                },
                recover: { key in
                    if isFailure {
                        throw URLError(
                            .notConnectedToInternet,
                        )
                    }
                    onRecover?(
                        key,
                    )
                    return ManageSubscriptionPreviewFactory.makeStatus(
                        source: .yookassa,
                    )
                },
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

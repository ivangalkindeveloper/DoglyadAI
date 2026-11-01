#if DEBUG
    import Combine
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
                model.emit(
                    state,
                    animation: nil,
                )
            }
            return model
        }
    }
#endif

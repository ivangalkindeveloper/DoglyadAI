#if DEBUG
    @MainActor
    final class SubscriptionPreviewRepositoryFactory: SubscriptionRepositoryFactoryProtocol {
        private let repository: SubscriptionRepositoryProtocol

        init(
            repository: SubscriptionRepositoryProtocol,
        ) {
            self.repository = repository
        }

        func make() async -> SubscriptionRepositoryProtocol {
            repository
        }
    }
#endif

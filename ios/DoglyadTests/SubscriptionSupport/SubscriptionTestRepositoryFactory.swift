@testable import Doglyad

@MainActor
final class SubscriptionTestRepositoryFactory: SubscriptionRepositoryFactoryProtocol {
    private let makeRepository: () async -> SubscriptionRepositoryProtocol

    init(
        makeRepository: @escaping () async -> SubscriptionRepositoryProtocol,
    ) {
        self.makeRepository = makeRepository
    }

    func make() async -> SubscriptionRepositoryProtocol {
        await makeRepository()
    }
}

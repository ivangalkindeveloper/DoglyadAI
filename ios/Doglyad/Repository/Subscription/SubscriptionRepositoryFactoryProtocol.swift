@MainActor
protocol SubscriptionRepositoryFactoryProtocol {
    func make() async -> SubscriptionRepositoryProtocol
}

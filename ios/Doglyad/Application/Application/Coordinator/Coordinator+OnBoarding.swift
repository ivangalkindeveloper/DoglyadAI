extension Coordinator {
    func navigateAfterOnBoarding() async throws {
        let status = try await refreshSubscriptionStatus()
        switch status {
        case .some:
            root(.scan, animated: true)
        case .none:
            root(.subscriptionPaywall, animated: true)
        }
    }

    func resetToOnBoarding() {
        popRoot()
        root(.onBoarding, animated: true)
    }
}

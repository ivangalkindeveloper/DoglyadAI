extension Coordinator {
    func prepareConclusionGeneration() async throws -> NavigationResolution {
        let status = try await refreshSubscriptionStatus()
        guard let status else {
            screen(.subscriptionPaywall)
            return .routed
        }

        guard status.availableCountPerDay > 0 else {
            sheet(
                .requestLimitExceeded,
                arguments: RequestLimitExceededArguments()
            )
            return .routed
        }

        return .proceed
    }

    func run(
        _ feature: PaidFeature,
        dismissesSheetOnPaywall: Bool = false,
        onAvailable: () -> Void
    ) {
        switch getSubscriptionStatus()?.availability(of: feature) ?? .unavailable {
        case .available:
            onAvailable()
        case .offered:
            showPaywall(dismissingSheet: dismissesSheetOnPaywall)
        case .unavailable:
            break
        }
    }

    func showPaywall(
        dismissingSheet: Bool = false
    ) {
        if dismissingSheet {
            dismissSheet()
        }
        screen(.subscriptionPaywall)
    }

    func dismissPaywall() {
        if router.path.isEmpty {
            root(.scan)
        } else {
            pop()
        }
    }

    func refreshSubscriptionStatus() async throws -> SubscriptionStatus? {
        let status = try await subscriptionRepository.fetchStatus(
            configEntitlements: applicationConfig.entitlements
        )
        onSubscriptionStatusUpdated(status)
        return status
    }
}

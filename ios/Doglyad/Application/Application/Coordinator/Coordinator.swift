import Router
import SwiftUI

@MainActor
final class Coordinator {
    let router: DRouter
    let subscriptionRepository: SubscriptionRepositoryProtocol
    let applicationConfig: ApplicationConfig
    let getSubscriptionStatus: () -> SubscriptionStatus?
    let onSubscriptionStatusUpdated: (SubscriptionStatus?) -> Void

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
    ) {
        self.router = router
        subscriptionRepository = container.subscriptionRepository
        applicationConfig = container.applicationConfig
        self.getSubscriptionStatus = getSubscriptionStatus
        self.onSubscriptionStatusUpdated = onSubscriptionStatusUpdated
    }

    func screen(
        _ screen: ScreenType,
        arguments: RouteArgumentsProtocol? = nil,
    ) {
        router.push(
            route: RouteScreen(
                type: screen,
                arguments: arguments,
            ),
        )
    }

    func sheet(
        _ sheet: SheetType,
        arguments: RouteArgumentsProtocol? = nil,
    ) {
        router.push(
            route: RouteSheet(
                type: sheet,
                arguments: arguments,
            ),
        )
    }

    func root(
        _ screen: ScreenType,
        arguments: RouteArgumentsProtocol? = nil,
        isAnimated: Bool = false,
    ) {
        if isAnimated {
            withAnimation {
                router.root(
                    route: RouteScreen(
                        type: screen,
                        arguments: arguments,
                    ),
                )
            }
        } else {
            router.root(
                route: RouteScreen(
                    type: screen,
                    arguments: arguments,
                ),
            )
        }
    }

    func pop() {
        router.pop()
    }

    func popRoot() {
        router.popRoot()
    }

    func dismissSheet() {
        router.dismissSheet()
    }
}

extension Coordinator {
    func navigateAfterOnBoarding() async throws {
        let status = try await refreshSubscriptionStatus()
        switch status {
        case .some:
            root(
                .scan,
                isAnimated: true,
            )
        case .none:
            root(
                .subscriptionPaywall,
                isAnimated: true,
            )
        }
    }

    func resetToOnBoarding() {
        popRoot()
        root(
            .onBoarding,
            isAnimated: true,
        )
    }

    func prepareReportGeneration() async throws -> NavigationResolution {
        let status = try await refreshSubscriptionStatus()
        guard let status else {
            screen(
                .subscriptionPaywall,
            )
            return .routed
        }

        guard status.availableCountPerDay > 0 else {
            sheet(
                .requestLimitExceeded,
                arguments: RequestLimitExceededArguments(),
            )
            return .routed
        }

        return .proceed
    }

    func run(
        _ feature: PaidFeature,
        isSheetDismissedOnPaywall: Bool = false,
        onAvailable: () -> Void,
    ) {
        switch getSubscriptionStatus()?.availability(
            of: feature,
        ) ?? .unavailable {
        case .available:
            onAvailable()
        case .offered:
            showPaywall(
                isSheetDismissalRequired: isSheetDismissedOnPaywall,
            )
        case .unavailable:
            break
        }
    }

    func showPaywall(
        isSheetDismissalRequired: Bool = false,
    ) {
        if isSheetDismissalRequired {
            dismissSheet()
        }
        screen(
            .subscriptionPaywall,
        )
    }

    func dismissPaywall() {
        if router.path.isEmpty {
            root(
                .scan,
            )
        } else {
            pop()
        }
    }

    func refreshSubscriptionStatus() async throws -> SubscriptionStatus? {
        let status = try await subscriptionRepository.fetchStatus(
            configEntitlements: applicationConfig.entitlements,
        )
        onSubscriptionStatusUpdated(
            status,
        )
        return status
    }

    func selectNeuralModel(
        _ model: USExaminationNeuralModel,
        onSelected: (USExaminationNeuralModel) async throws -> Void,
    ) async throws {
        switch model.accessibility {
        case .available:
            break
        case .comingSoon, .unavailable:
            return
        }

        switch model.entitlement {
        case .base:
            try await onSelected(
                model,
            )
            dismissSheet()
        case .pro:
            switch getSubscriptionStatus()?.type {
            case .some(
                .pro,
            ):
                try await onSelected(
                    model,
                )
                dismissSheet()
            case .some(
                .base,
            ), .none:
                showPaywall(
                    isSheetDismissalRequired: true,
                )
            }
        }
    }

    static func initialRoute(
        for context: InitialNavigationContext,
    ) -> RouteScreen<ScreenType> {
        let applicationConfig = context.applicationConfig

        guard context.isOnBoardingCompleted,
              context.selectedUSExaminationTypeId != nil
        else {
            return RouteScreen(
                type: .onBoarding,
            )
        }

        let acceptedLegalDate = context.acceptedLegalDocumentDate ?? .distantPast
        if acceptedLegalDate < applicationConfig.legalDate {
            return RouteScreen(
                type: .legalUpdate,
            )
        }

        if context.conclusionsCount == 0,
           context.subscriptionStatus == nil
        {
            return RouteScreen(
                type: .subscriptionPaywall,
            )
        }

        return RouteScreen(
            type: .scan,
        )
    }
}

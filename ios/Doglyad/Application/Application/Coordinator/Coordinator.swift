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
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void
    ) {
        self.router = router
        subscriptionRepository = container.subscriptionRepository
        applicationConfig = container.applicationConfig
        self.getSubscriptionStatus = getSubscriptionStatus
        self.onSubscriptionStatusUpdated = onSubscriptionStatusUpdated
    }

    func screen(
        _ screen: ScreenType,
        arguments: RouteArgumentsProtocol? = nil
    ) {
        router.push(
            route: RouteScreen(
                type: screen,
                arguments: arguments
            )
        )
    }

    func sheet(
        _ sheet: SheetType,
        arguments: RouteArgumentsProtocol? = nil
    ) {
        router.push(
            route: RouteSheet(
                type: sheet,
                arguments: arguments
            )
        )
    }

    func root(
        _ screen: ScreenType,
        arguments: RouteArgumentsProtocol? = nil,
        animated: Bool = false
    ) {
        if animated {
            withAnimation {
                router.root(
                    route: RouteScreen(
                        type: screen,
                        arguments: arguments
                    )
                )
            }
        } else {
            router.root(
                route: RouteScreen(
                    type: screen,
                    arguments: arguments
                )
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

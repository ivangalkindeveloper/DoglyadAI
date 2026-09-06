import Foundation

@MainActor
final class WebDocumentViewModel: DViewModel {
    let url: URL
    let title: LocalizedStringResource

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: WebDocumentBottomSheetArguments
    ) {
        url = arguments.url
        title = arguments.title
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.webDocument),
            analyticsParameters: AnalyticsParameters([
                .document: .string(AnalyticsDocument(url: arguments.url).rawValue),
            ])
        )
    }
}

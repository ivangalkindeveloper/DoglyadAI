import UIKit

@MainActor
final class PhotoLibraryPickerViewModel: DViewModel {
    private let arguments: PhotoLibraryPickerArguments

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: PhotoLibraryPickerArguments
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.photoLibraryPicker),
            analyticsParameters: AnalyticsParameters([
                .selectionLimit: .int(arguments.selectionLimit),
            ])
        )
    }

    var selectionLimit: Int {
        arguments.selectionLimit
    }

    func onComplete(_ images: [UIImage]) {
        if images.isEmpty {
            analytics.buttonTapped(.photoLibraryCancel)
        } else {
            analytics.buttonTapped(
                .photoLibraryComplete,
                parameters: AnalyticsParameters([
                    .itemCount: .int(images.count),
                ])
            )
        }
        coordinator.dismissSheet()
        arguments.onComplete(images)
    }
}

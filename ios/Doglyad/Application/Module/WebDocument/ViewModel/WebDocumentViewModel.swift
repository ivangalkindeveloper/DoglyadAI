import Combine
import Foundation
import SwiftUI

@MainActor
final class WebDocumentViewModel: DModuleViewModel<any WebDocumentStateProtocol> {
    let url: URL

    let title: LocalizedStringResource

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: WebDocumentArguments,
    ) {
        url = arguments.url
        title = arguments.title

        super.init(
            state: WebDocumentLoadingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .webDocument,
            ),
            analyticsParameters: .document(
                url: arguments.url,
            ),
        )
    }

    func onDocumentLoaded() {
        emit(
            WebDocumentLoadedState(),
        )
    }

    func onDocumentFailed(
        _ error: Error,
    ) {
        emit(
            WebDocumentFailedState(
                error: error,
            ),
        )
    }

    static func insetString(
        _ value: CGFloat,
    ) -> String {
        String(
            format: "%.2f",
            max(
                value,
                0,
            ),
        )
    }
}

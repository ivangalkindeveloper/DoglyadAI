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
        onRefreshSubscriptionStatus: @escaping () async -> Void,
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
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            analyticsDestination: .bottomSheet(
                .webDocument,
            ),
            analyticsParameters: .document(
                url: arguments.url,
            ),
        )
    }

    var documentStateIdentifier: String {
        switch state {
        case _ as WebDocumentSuccessState: "webDocument.loaded"
        case _ as WebDocumentFailedState: "webDocument.failed"
        default: "webDocument.loading"
        }
    }

    func onTapRetry() {
        switch state {
        case _ as WebDocumentFailedState:
            emit(
                WebDocumentLoadingState(),
            )
        default: break
        }
    }

    func onDocumentLoaded(
        from sourceState: any WebDocumentStateProtocol,
    ) {
        guard state === sourceState else {
            return
        }
        #if DEBUG
            guard !isPreviewSnapshot else {
                return
            }
        #endif
        emit(
            WebDocumentSuccessState(),
        )
    }

    func onDocumentFailed(
        _ error: Error,
        from sourceState: any WebDocumentStateProtocol,
    ) {
        guard state === sourceState else {
            return
        }
        #if DEBUG
            guard !isPreviewSnapshot else {
                return
            }
        #endif
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

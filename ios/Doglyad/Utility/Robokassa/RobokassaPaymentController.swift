import AuthenticationServices
import Foundation
import UIKit

@MainActor
final class RobokassaPaymentController: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<Bool, Error>?
    private var window: UIWindow?

    func open(
        url: URL,
    ) async throws -> Bool {
        try Task.checkCancellation()
        guard url.scheme == "https", session == nil else {
            throw SubscriptionError.offeringsUnavailable
        }
        window = UIApplication.shared.connectedScenes.compactMap {
            $0 as? UIWindowScene
        }
        .flatMap(
            \.windows,
        ).first {
            $0.isKeyWindow
        }
        guard window != nil else {
            throw SubscriptionError.offeringsUnavailable
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: "doglyad",
                ) { [weak self] callback, error in
                    Task { @MainActor in
                        guard let self else {
                            return
                        }
                        if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                            self.finish(
                                .success(
                                    false,
                                ),
                            )
                        } else if let error {
                            self.finish(
                                .failure(
                                    error,
                                ),
                            )
                        } else {
                            self.finish(
                                .success(
                                    callback?.host == "subscription" && callback?.path == "/complete",
                                ),
                            )
                        }
                    }
                }
                session.presentationContextProvider = self
                self.session = session
                if !session.start() {
                    finish(
                        .failure(
                            SubscriptionError.offeringsUnavailable,
                        ),
                    )
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.session?.cancel()
                self.finish(
                    .failure(
                        CancellationError(),
                    ),
                )
            }
        }
    }

    func presentationAnchor(
        for _: ASWebAuthenticationSession,
    ) -> ASPresentationAnchor {
        window ?? ASPresentationAnchor()
    }

    private func finish(
        _ result: Result<Bool, Error>,
    ) {
        let pending = continuation
        continuation = nil
        session = nil
        window = nil
        pending?.resume(
            with: result,
        )
    }
}

import Foundation
import UIKit
import YooKassaPayments

@MainActor
final class YooKassaPaymentController: YooKassaDelegate {
    private let testModeSettings: TestModeSettings?
    private var operationID: UUID?
    private var tokenizationContinuation: CheckedContinuation<String?, Error>?
    private var confirmationContinuation: CheckedContinuation<Void, Error>?
    private var sdkViewController: UIViewController?
    private var isDismissalRequested = false

    init(
        testModeSettings: TestModeSettings? = nil,
    ) {
        self.testModeSettings = testModeSettings
    }

    func tokenize(
        preparation: BillingPreparePaymentResponse,
    ) async throws -> String? {
        try Task.checkCancellation()
        guard sdkViewController == nil else {
            throw SubscriptionError.purchasePending
        }
        let presenter = try presenter()
        let operationID = UUID()
        self.operationID = operationID
        isDismissalRequested = false
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(
                        throwing: CancellationError(),
                    )
                    return
                }
                tokenizationContinuation = continuation
                let controller = makeController(
                    preparation: preparation,
                )
                sdkViewController = controller
                presenter.present(
                    controller,
                    animated: true,
                )
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, self.operationID == operationID else {
                    return
                }
                fail(
                    CancellationError(),
                )
            }
        }
    }

    func confirm(
        payment: BillingPaymentResponse,
        preparation: BillingPreparePaymentResponse,
    ) async throws {
        try Task.checkCancellation()
        guard !isDismissalRequested, let url = payment.confirmationUrl, url.scheme == "https" else {
            return
        }
        let method: PaymentMethodType
        switch payment.paymentMethodType {
        case "bank_card": method = .bankCard
        case "sbp": method = .sbp
        default: return
        }
        let presenter = sdkViewController == nil ? try presenter() : nil
        if sdkViewController == nil {
            operationID = UUID()
            sdkViewController = makeController(
                preparation: preparation,
            )
        }
        let operationID = operationID
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(
                        throwing: CancellationError(),
                    )
                    return
                }
                confirmationContinuation = continuation
                let runConfirmation = {
                    do {
                        try YooKassa.runConfirmation(
                            config: ConfirmationConfig(
                                confirmationUrl: url.absoluteString,
                                paymentMethodType: method,
                            ),
                        )
                    } catch {
                        self.fail(
                            error,
                        )
                    }
                }
                if let presenter, let controller = sdkViewController {
                    presenter.present(
                        controller,
                        animated: true,
                        completion: runConfirmation,
                    )
                } else {
                    runConfirmation()
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, self.operationID == operationID else {
                    return
                }
                fail(
                    CancellationError(),
                )
            }
        }
    }

    func close() async {
        operationID = nil
        isDismissalRequested = false
        fail(
            CancellationError(),
        )
        let controller = sdkViewController
        sdkViewController = nil
        guard let controller, controller.presentingViewController != nil else {
            return
        }
        await withCheckedContinuation { continuation in
            controller.dismiss(
                animated: true,
            ) {
                continuation.resume()
            }
        }
    }

    static func handleOpen(
        url: URL,
    ) {
        guard url.scheme == "doglyad" else {
            return
        }
        YooKassa.handleOpen(
            url: url,
        )
    }

    func yooKassa(
        _: Any,
        didTokenize token: Tokens,
        paymentMethodType _: PaymentMethodType,
    ) {
        let continuation = tokenizationContinuation
        tokenizationContinuation = nil
        continuation?.resume(
            returning: token.paymentToken,
        )
    }

    func yooKassa(
        _: Any,
        didFinish error: Error?,
    ) {
        isDismissalRequested = true
        if let error {
            fail(
                error,
            )
            return
        }
        let tokenization = tokenizationContinuation
        tokenizationContinuation = nil
        tokenization?.resume(
            returning: nil,
        )
        finishConfirmation()
    }

    func yooKassa(
        _: Any,
        didFinishConfirmation _: PaymentStatus,
    ) {
        // The server checks the canonical payment after this advisory SDK callback.
        finishConfirmation()
    }

    func yooKassa(
        _: Any,
        didFailConfirmation _: Error,
    ) {
        finishConfirmation()
    }

    private func finishConfirmation() {
        let continuation = confirmationContinuation
        confirmationContinuation = nil
        continuation?.resume()
    }

    private func fail(
        _ error: Error,
    ) {
        let tokenization = tokenizationContinuation
        let confirmation = confirmationContinuation
        tokenizationContinuation = nil
        confirmationContinuation = nil
        tokenization?.resume(
            throwing: error,
        )
        confirmation?.resume(
            throwing: error,
        )
    }

    private func makeController(
        preparation: BillingPreparePaymentResponse,
    ) -> UIViewController {
        let data = TokenizationModuleInputData(
            clientApplicationKey: preparation.clientApplicationKey,
            shopName: preparation.shopName,
            shopId: preparation.shopId,
            purchaseDescription: preparation.description,
            amount: Amount(
                value: Decimal(
                    preparation.price.amountMinor,
                ) / 100,
                currency: .rub,
            ),
            tokenizationSettings: TokenizationSettings(
                paymentMethodTypes: [.bankCard, .sbp],
            ),
            testModeSettings: testModeSettings,
            isLoggingEnabled: false,
            savePaymentMethod: .on,
            applicationScheme: "doglyad://",
            lang: Locale.current.language.languageCode?.identifier == "ru" ? "ru" : "en",
        )
        let controller = YooKassa.makeTokenizationController(
            config: TokenizationConfig(
                flow: .tokenization(
                    data,
                ),
            ),
            delegate: self,
        )
        controller.modalPresentationStyle = .overFullScreen
        controller.isModalInPresentation = true
        return controller
    }

    private func presenter() throws -> UIViewController {
        let scene = UIApplication.shared.connectedScenes.compactMap {
            $0 as? UIWindowScene
        }.first { scene in
            switch scene.activationState {
            case .foregroundActive: true
            case .foregroundInactive, .background, .unattached: false
            @unknown default: false
            }
        }
        guard var controller = scene?.windows.first(
            where: {
                $0.isKeyWindow
            },
        )?.rootViewController else {
            throw SubscriptionError.offeringsUnavailable
        }
        while let presented = controller.presentedViewController {
            controller = presented
        }
        guard !controller.isBeingDismissed else {
            throw SubscriptionError.offeringsUnavailable
        }
        return controller
    }
}

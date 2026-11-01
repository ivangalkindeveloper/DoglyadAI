@testable import Doglyad
import Foundation
import UIKit
import XCTest
import YooKassaPayments

// XCTest runs this UIKit integration check outside the parallel Swift Testing
// suites that also replace the application's key window.
final class YooKassaSDKPresentationTests: XCTestCase {
    @MainActor
    func testOfficialSDKMockFormOpensAndCancellationClosesIt() async throws {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive },
        )
        let previousKeyWindow = scene.keyWindow
        let presenter = UIViewController()
        let window = UIWindow(
            windowScene: scene,
        )
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        presenter.view.layoutIfNeeded()
        let controller = YooKassaPaymentController(
            testModeSettings: TestModeSettings(
                paymentAuthorizationPassed: false,
                cardsCount: 2,
                charge: Amount(
                    value: 100,
                    currency: .rub,
                ),
                enablePaymentError: false,
            ),
        )
        let preparation = try JSONDecoder().decode(
            BillingPreparePaymentResponse.self,
            from: Data(
                """
                {"payment":{"id":"\(UUID().uuidString)","planId":"monthly","status":"awaitingToken","confirmationUrl":null,"paymentMethodType":null},
                "shopId":"123","clientApplicationKey":"test-only","shopName":"Doglyad","description":"SDK mock UI",
                "termsVersion":"test-v1","price":{"amountMinor":10000,"currencyIso2Code":"RUB"}}
                """.utf8,
            ),
        )
        let task = Task { try await controller.tokenize(
            preparation: preparation,
        ) }
        do {
            for _ in 0 ..< 100 {
                if presenter.presentedViewController?.viewIfLoaded?.window != nil { break }
                try await Task.sleep(
                    for: .milliseconds(
                        50,
                    ),
                )
            }
            let sdk = try XCTUnwrap(
                presenter.presentedViewController,
            )
            XCTAssertTrue(
                sdk.viewIfLoaded?.window != nil,
            )
            XCTAssertTrue(
                sdk.isModalInPresentation,
            )
            // Allow the presentation animation to finish before testing cancellation.
            try await Task.sleep(
                for: .milliseconds(
                    500,
                ),
            )
            task.cancel()
            do {
                _ = try await task.value
                XCTFail(
                    "The canceled payment form must throw CancellationError",
                )
            } catch is CancellationError {}
            await controller.close()
            XCTAssertTrue(
                presenter.presentedViewController == nil,
            )
        } catch {
            task.cancel()
            await controller.close()
            throw error
        }
    }
}

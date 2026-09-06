@testable import DoglyadUI
import Testing
import UIKit

@MainActor
struct DInteractivePopGestureControllerTests {
    @Test
    func enablesGestureOnlyWhenNavigationCanPop() throws {
        let rootController = UIViewController()
        let navigationController = UINavigationController(rootViewController: rootController)
        navigationController.loadViewIfNeeded()

        let controller = DInteractivePopGestureController()
        navigationController.pushViewController(controller, animated: false)
        controller.loadViewIfNeeded()

        let gestureRecognizer = try #require(navigationController.interactivePopGestureRecognizer)
        controller.installInteractivePopGesture()

        #expect(gestureRecognizer.delegate === controller)
        #expect(gestureRecognizer.isEnabled)
        #expect(controller.gestureRecognizerShouldBegin(gestureRecognizer))

        navigationController.setViewControllers([controller], animated: false)

        #expect(!controller.gestureRecognizerShouldBegin(gestureRecognizer))
    }
}

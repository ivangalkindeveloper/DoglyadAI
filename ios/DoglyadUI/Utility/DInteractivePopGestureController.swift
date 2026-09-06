import UIKit

final class DInteractivePopGestureController: UIViewController, UIGestureRecognizerDelegate {
    private weak var installedNavigationController: UINavigationController?
    private weak var previousDelegate: UIGestureRecognizerDelegate?
    private var previousIsEnabled: Bool?

    override func loadView() {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        self.view = view
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installInteractivePopGesture()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)

        guard parent != nil else {
            restoreInteractivePopGesture()
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.installInteractivePopGesture()
        }
    }

    func installInteractivePopGesture() {
        guard
            let navigationController,
            let gestureRecognizer = navigationController.interactivePopGestureRecognizer
        else { return }

        if installedNavigationController !== navigationController {
            restoreInteractivePopGesture()
            installedNavigationController = navigationController
            previousDelegate = gestureRecognizer.delegate
            previousIsEnabled = gestureRecognizer.isEnabled
        }

        gestureRecognizer.delegate = self
        gestureRecognizer.isEnabled = true
    }

    func restoreInteractivePopGesture() {
        guard
            let installedNavigationController,
            let gestureRecognizer = installedNavigationController.interactivePopGestureRecognizer,
            gestureRecognizer.delegate === self
        else {
            self.installedNavigationController = nil
            previousDelegate = nil
            previousIsEnabled = nil
            return
        }

        gestureRecognizer.delegate = previousDelegate
        if let previousIsEnabled {
            gestureRecognizer.isEnabled = previousIsEnabled
        }

        self.installedNavigationController = nil
        previousDelegate = nil
        previousIsEnabled = nil
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard
            let installedNavigationController,
            gestureRecognizer === installedNavigationController.interactivePopGestureRecognizer
        else { return false }

        return installedNavigationController.viewControllers.count > 1
            && installedNavigationController.transitionCoordinator == nil
    }
}

import SwiftUI

struct DInteractivePopGestureView: UIViewControllerRepresentable {
    func makeUIViewController(
        context _: Context
    ) -> DInteractivePopGestureController {
        DInteractivePopGestureController()
    }

    func updateUIViewController(
        _ uiViewController: DInteractivePopGestureController,
        context _: Context
    ) {
        DispatchQueue.main.async { [weak uiViewController] in
            uiViewController?.installInteractivePopGesture()
        }
    }

    static func dismantleUIViewController(
        _ uiViewController: DInteractivePopGestureController,
        coordinator _: Void
    ) {
        uiViewController.restoreInteractivePopGesture()
    }
}

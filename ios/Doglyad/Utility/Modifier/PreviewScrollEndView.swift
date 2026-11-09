#if DEBUG
    import SwiftUI
    import UIKit

    /// Moves real scroll containers, including WebKit documents, after their layout settles.
    struct PreviewScrollEndView: UIViewRepresentable {
        func makeUIView(
            context: Context,
        ) -> UIView {
            let probe = UIView()
            probe.isAccessibilityElement = true
            probe.accessibilityIdentifier = "preview.scrollEnd.waiting"
            context.coordinator.start(
                probe: probe,
            )
            return probe
        }

        func updateUIView(
            _: UIView,
            context _: Context,
        ) {}

        func makeCoordinator() -> PreviewScrollEndController {
            PreviewScrollEndController()
        }

        static func dismantleUIView(
            _: UIView,
            coordinator: PreviewScrollEndController,
        ) {
            coordinator.stop()
        }
    }
#endif

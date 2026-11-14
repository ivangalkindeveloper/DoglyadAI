@testable import Doglyad
import Testing
import UIKit

@Suite(
    .serialized,
)
@MainActor
struct PreviewScrollEndTests {
    init() {}

    @Test
    func scrollsToTheRealBottomIncludingContentInsets() async throws {
        let window = UIWindow(
            frame: CGRect(
                x: 0,
                y: 0,
                width: 390,
                height: 844,
            ),
        )
        let root = UIViewController()
        window.rootViewController = root
        root.view.frame = window.bounds
        window.isHidden = false
        defer {
            window.isHidden = true
        }
        let scroll = UIScrollView(
            frame: root.view.bounds,
        )
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.contentInset = UIEdgeInsets(
            top: 100,
            left: 0,
            bottom: 127,
            right: 0,
        )
        scroll.contentSize = CGSize(
            width: 390,
            height: 2200,
        )
        root.view.addSubview(
            scroll,
        )
        // A multiline field must retain its own position while the screen scrolls.
        let field = UITextView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: 300,
                height: 100,
            ),
        )
        field.contentInsetAdjustmentBehavior = .never
        field.text = String(
            repeating: "Test\n",
            count: 30,
        )
        field.contentSize = CGSize(
            width: 300,
            height: 500,
        )
        scroll.addSubview(
            field,
        )
        field.layoutIfNeeded()
        field.setContentOffset(
            CGPoint(
                x: 0,
                y: 20,
            ),
            animated: false,
        )
        let probe = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: 1,
                height: 1,
            ),
        )
        root.view.addSubview(
            probe,
        )
        let controller = PreviewScrollEndController()
        defer {
            controller.stop()
        }
        controller.start(
            probe: probe,
        )
        try await waitForScrollEnd(
            probe,
        )
        #expect(
            abs(
                scroll.contentOffset.y - (2200 - scroll.bounds.height + 127),
            ) < 1,
        )
        #expect(
            field.contentOffset.y == 20,
        )
    }

    @Test
    func shortContentHasNoArtificialScrollOffset() async throws {
        let window = UIWindow(
            frame: CGRect(
                x: 0,
                y: 0,
                width: 390,
                height: 844,
            ),
        )
        let root = UIViewController()
        window.rootViewController = root
        root.view.frame = window.bounds
        window.isHidden = false
        defer {
            window.isHidden = true
        }
        let scroll = UIScrollView(
            frame: root.view.bounds,
        )
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.contentSize = CGSize(
            width: 390,
            height: 200,
        )
        root.view.addSubview(
            scroll,
        )
        let probe = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: 1,
                height: 1,
            ),
        )
        root.view.addSubview(
            probe,
        )
        let controller = PreviewScrollEndController()
        defer {
            controller.stop()
        }
        controller.start(
            probe: probe,
        )
        try await waitForScrollEnd(
            probe,
        )
        #expect(
            scroll.contentOffset.y == 0,
        )
    }

    private func waitForScrollEnd(
        _ probe: UIView,
    ) async throws {
        let deadline = ContinuousClock.now.advanced(
            by: .seconds(
                20,
            ),
        )
        while probe.accessibilityIdentifier != "preview.scrollEnd.ready", ContinuousClock.now < deadline {
            try await Task.sleep(
                for: .milliseconds(
                    50,
                ),
            )
        }
        try #require(
            probe.accessibilityIdentifier == "preview.scrollEnd.ready",
        )
    }
}

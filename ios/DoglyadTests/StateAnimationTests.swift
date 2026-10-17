@testable import Doglyad
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(
    .serialized,
)
struct StateAnimationTests {
    @Test
    func initialStateIsNotAnimatedAndEmitUsesDefaultAnimation() async throws {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
        )
        let previousKeyWindow = scene.keyWindow
        let model = DStateViewModel(
            state: 0,
        )
        var rendered: [(state: Int, animation: Animation?)] = []
        let hosting = UIHostingController(
            rootView: StateAnimationProbeView(
                viewModel: model,
                onTransaction: { value, animation in
                    rendered.append(
                        (state: value, animation: animation),
                    )
                },
            ),
        )
        let window = UIWindow(
            windowScene: scene,
        )
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = hosting
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        hosting.view.layoutIfNeeded()
        try await waitForRender { rendered.contains { $0.state == 0 } }
        let initial = try #require(
            rendered.first { $0.state == 0 },
        )
        #expect(
            initial.animation == nil,
        )

        model.emit(
            1,
        )
        try await waitForRender { rendered.contains { $0.state == 1 } }
        let updated = try #require(
            rendered.first { $0.state == 1 },
        )
        #expect(
            updated.animation == .easeInOut(
                duration: 0.35,
            ),
        )
    }

    private func waitForRender(
        _ isRendered: () -> Bool,
    ) async throws {
        for _ in 0 ..< 200 {
            if isRendered() { return }
            try await Task.sleep(
                for: .milliseconds(
                    10,
                ),
            )
        }
        Issue.record(
            "SwiftUI did not render the requested state",
        )
    }
}

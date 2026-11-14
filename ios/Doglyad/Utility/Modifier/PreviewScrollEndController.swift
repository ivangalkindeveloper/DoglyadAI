#if DEBUG
    import UIKit
    import WebKit

    @MainActor
    final class PreviewScrollEndController {
        private var task: Task<Void, Never>?

        init() {}

        func start(
            probe: UIView,
        ) {
            task?.cancel()
            task = Task { [weak self, weak probe] in
                var stableSamples = 0
                var previousHeights: [CGFloat] = []
                // Sheet detents, lazy lists and bundled HTML all finish asynchronously.
                for _ in 0 ..< 150 {
                    do {
                        try await Task.sleep(
                            for: .milliseconds(
                                100,
                            ),
                        )
                    } catch {
                        return
                    }
                    guard let self, let probe, let window = probe.window else {
                        continue
                    }
                    let scrollViews = scrollViews(
                        in: window,
                    )
                    guard !scrollViews.isEmpty else {
                        continue
                    }
                    let heights = scrollViews.map(
                        \.contentSize.height,
                    )
                    var isReady = heights == previousHeights
                    for scroll in scrollViews {
                        if let webView = scroll.superview as? WKWebView, webView.isLoading {
                            isReady = false
                            continue
                        }
                        scroll.layoutIfNeeded()
                        let end = max(
                            -scroll.adjustedContentInset.top,
                            scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom,
                        )
                        if abs(
                            scroll.contentOffset.y - end,
                        ) > 1 {
                            isReady = false
                            scroll.setContentOffset(
                                CGPoint(
                                    x: scroll.contentOffset.x,
                                    y: end,
                                ),
                                animated: false,
                            )
                        }
                    }
                    previousHeights = heights
                    stableSamples = isReady ? stableSamples + 1 : 0
                    if stableSamples >= 5 {
                        probe.accessibilityIdentifier = "preview.scrollEnd.ready"
                        return
                    }
                }
            }
        }

        func stop() {
            task?.cancel()
            task = nil
        }

        private func scrollViews(
            in view: UIView,
        ) -> [UIScrollView] {
            guard !view.isHidden, view.alpha > 0, let window = (view as? UIWindow) ?? view.window,
                  view.convert(
                      view.bounds,
                      to: window,
                  ).intersects(
                      window.bounds,
                  )
            else {
                return []
            }
            // Stop at the outer vertical container. Do not scroll text fields or photo carousels.
            if let scroll = view as? UIScrollView, !(scroll is UITextView),
               scroll.bounds.height > 0, scroll.bounds.width > 0,
               !scroll.isPagingEnabled,
               scroll.alwaysBounceVertical || scroll.contentSize.height > scroll.bounds.height || scroll.contentSize.width <= scroll.bounds.width + 1
            {
                return [scroll]
            }
            return view.subviews.flatMap {
                scrollViews(
                    in: $0,
                )
            }
        }
    }
#endif

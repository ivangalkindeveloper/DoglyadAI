import DoglyadUI
import SwiftUI
import WebKit

struct WebDocumentBottomSheetWebView: UIViewRepresentable, DViewProtocol {
    @Environment(
        \.locale,
    ) private var locale
    @EnvironmentObject var theme: DTheme

    let url: URL
    let topInset: CGFloat
    let bottomInset: CGFloat
    let onLoaded: () -> Void
    let onFailed: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            parent: self,
        )
    }

    func makeUIView(
        context: Context,
    ) -> WKWebView {
        let backgroundColor = UIColor(
            color.grayscaleBackgroundWeak,
        )
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
        webView.underPageBackgroundColor = backgroundColor
        webView.navigationDelegate = context.coordinator
        let language = locale.language.languageCode?.identifier ?? "en"
        var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false,
        )
        components?.queryItems = [
            URLQueryItem(
                name: "lang",
                value: language,
            ),
            URLQueryItem(
                name: "topInset",
                value: WebDocumentViewModel.insetString(
                    topInset,
                ),
            ),
            URLQueryItem(
                name: "bottomInset",
                value: WebDocumentViewModel.insetString(
                    bottomInset,
                ),
            ),
        ]
        var request = URLRequest(
            url: components?.url ?? url,
        )
        request.cachePolicy = .reloadIgnoringLocalCacheData
        webView.load(
            request,
        )
        return webView
    }

    func updateUIView(
        _ webView: WKWebView,
        context: Context,
    ) {
        context.coordinator.parent = self
        context.coordinator.applyInsets(
            to: webView,
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebDocumentBottomSheetWebView
        private var isLoaded = false
        private var appliedTopInset: CGFloat?
        private var appliedBottomInset: CGFloat?

        init(
            parent: WebDocumentBottomSheetWebView,
        ) {
            self.parent = parent
        }

        func applyInsets(
            to webView: WKWebView,
        ) {
            guard isLoaded else { return }
            let topInset = parent.topInset
            let bottomInset = parent.bottomInset
            guard appliedTopInset != topInset || appliedBottomInset != bottomInset else { return }
            appliedTopInset = topInset
            appliedBottomInset = bottomInset
            webView.evaluateJavaScript(
                "window.doglyadSetInsets && window.doglyadSetInsets("
                    + "\(WebDocumentViewModel.insetString(topInset)),"
                    + "\(WebDocumentViewModel.insetString(bottomInset)))",
            )
        }

        func webView(
            _: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void,
        ) {
            if let url = navigationAction.request.url,
               url.scheme == "mailto"
            {
                UIApplication.shared.open(
                    url,
                )
                decisionHandler(
                    .cancel,
                )
                return
            }
            decisionHandler(
                .allow,
            )
        }

        func webView(
            _ webView: WKWebView,
            didFinish _: WKNavigation!,
        ) {
            isLoaded = true
            applyInsets(
                to: webView,
            )
            parent.onLoaded()
        }

        func webView(
            _: WKWebView,
            didFail _: WKNavigation!,
            withError error: Error,
        ) {
            parent.onFailed(
                error,
            )
        }

        func webView(
            _: WKWebView,
            didFailProvisionalNavigation _: WKNavigation!,
            withError error: Error,
        ) {
            parent.onFailed(
                error,
            )
        }
    }
}

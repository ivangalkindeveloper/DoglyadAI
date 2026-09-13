import DoglyadUI
import SwiftUI
import WebKit

struct WebDocumentBottomSheetWebView: UIViewRepresentable, DView {
    @Environment(\.locale) private var locale
    @EnvironmentObject var theme: DTheme

    let url: URL
    let topInset: CGFloat
    let bottomInset: CGFloat
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let backgroundColor = UIColor(color.grayscaleBackgroundWeak)
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
        webView.underPageBackgroundColor = backgroundColor
        webView.navigationDelegate = context.coordinator
        let language = locale.language.languageCode?.identifier ?? "en"
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "lang", value: language),
            URLQueryItem(name: "topInset", value: Self.inset(topInset)),
            URLQueryItem(name: "bottomInset", value: Self.inset(bottomInset)),
        ]
        var request = URLRequest(url: components?.url ?? url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        webView.load(request)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyInsets(to: webView)
    }

    private static func inset(_ value: CGFloat) -> String {
        String(format: "%.2f", max(value, 0))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebDocumentBottomSheetWebView
        private var isLoaded = false
        private var appliedTopInset: CGFloat?
        private var appliedBottomInset: CGFloat?

        init(parent: WebDocumentBottomSheetWebView) {
            self.parent = parent
        }

        func applyInsets(to webView: WKWebView) {
            guard isLoaded else { return }
            let topInset = parent.topInset
            let bottomInset = parent.bottomInset
            guard appliedTopInset != topInset || appliedBottomInset != bottomInset else { return }
            appliedTopInset = topInset
            appliedBottomInset = bottomInset
            webView.evaluateJavaScript(
                "window.doglyadSetInsets && window.doglyadSetInsets("
                    + "\(WebDocumentBottomSheetWebView.inset(topInset)),"
                    + "\(WebDocumentBottomSheetWebView.inset(bottomInset)))"
            )
        }

        func webView(
            _: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               url.scheme == "mailto"
            {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            didFinish _: WKNavigation!
        ) {
            isLoaded = true
            applyInsets(to: webView)
            parent.isLoading = false
        }

        func webView(
            _: WKWebView,
            didFail _: WKNavigation!,
            withError _: Error
        ) {
            parent.isLoading = false
        }
    }
}

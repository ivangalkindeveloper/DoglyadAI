import DoglyadUI
import SwiftUI

struct WebDocumentContentView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: WebDocumentViewModel
    let state: any WebDocumentStateProtocol
    let topInset: CGFloat
    let bottomInset: CGFloat

    var body: some View {
        ZStack {
            WebDocumentBottomSheetWebView(
                url: viewModel.url,
                topInset: topInset,
                bottomInset: bottomInset,
                onLoaded: {
                    viewModel.onDocumentLoaded(
                        from: state,
                    )
                },
                onFailed: {
                    viewModel.onDocumentFailed(
                        $0,
                        from: state,
                    )
                },
                stateIdentifier: viewModel.documentStateIdentifier,
            )

            switch state {
            case _ as WebDocumentLoadingState:
                color.grayscaleBackground
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                    )
                    .dShimmer(
                        cornerRadius: 0,
                    )
            default:
                EmptyView()
            }
        }
    }
}

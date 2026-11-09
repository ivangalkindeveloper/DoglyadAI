import DoglyadUI
import SwiftUI

struct WebDocumentContentView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: WebDocumentViewModel
    let state: any WebDocumentStateProtocol
    let topInset: CGFloat
    let bottomInset: CGFloat

    var body: some View {
        #if DEBUG
            let html = viewModel.previewHTML
        #else
            let html: String? = nil
        #endif

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
                html: html,
            )

            switch state {
            case _ as WebDocumentLoadingState:
                DScrollVStack(
                    spacing: size.s24,
                    padding: EdgeInsets(
                        top: topInset + size.s16,
                        leading: size.s16,
                        bottom: bottomInset + size.s16,
                        trailing: size.s16,
                    ),
                ) {
                    ForEach(
                        0 ..< 3,
                        id: \.self,
                    ) { _ in
                        VStack(
                            alignment: .leading,
                            spacing: size.s16,
                        ) {
                            DShimmerTextLines(
                                lineHeight: size.s24,
                                lineWidths: [0.65],
                            )

                            DShimmerTextLines(
                                lineHeight: size.s20,
                                lineWidths: [0.9, 0.75, 0.86, 0.58, 0.8],
                            )
                        }
                    }
                }
                .background(
                    color.grayscaleBackgroundWeak,
                )
            default:
                EmptyView()
            }
        }
    }
}

import DoglyadUI
import SwiftUI

struct WebDocumentBottomSheetView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: WebDocumentViewModel

    var body: some View {
        let stateIdentifier = viewModel.state is WebDocumentLoadedState
            ? "webDocument.loaded"
            : viewModel.state is WebDocumentFailedState ? "webDocument.failed" : "webDocument.loading"

        DBottomSheet(
            title: viewModel.title,
            fraction: 0.8,
        ) { toolbarHeight, bottomHeight in
            ZStack {
                WebDocumentBottomSheetWebView(
                    url: viewModel.url,
                    topInset: toolbarHeight,
                    bottomInset: bottomHeight,
                    onLoaded: viewModel.onDocumentLoaded,
                    onFailed: viewModel.onDocumentFailed,
                    stateIdentifier: stateIdentifier,
                )

                switch viewModel.state {
                case _ as WebDocumentLoadingState:
                    color.grayscaleBackground
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                        )
                        .dShimmer(
                            cornerRadius: 0,
                        )
                case _ as WebDocumentLoadedState, _ as WebDocumentFailedState:
                    EmptyView()
                default: EmptyView()
                }
            }
            .edgesIgnoringSafeArea(
                .bottom,
            )
        }
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}

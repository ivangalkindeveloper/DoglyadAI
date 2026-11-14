import DoglyadUI
import SwiftUI

struct WebDocumentBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: WebDocumentViewModel

    init(
        viewModel: @autoclosure @escaping () -> WebDocumentViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DBottomSheet(
            title: viewModel.title,
            fraction: 0.8,
            content: { toolbarHeight, bottomHeight in
                switch viewModel.state {
                case _ as WebDocumentErrorState:
                    ErrorBodyView(
                        description: l10n.text(
                            .errorUnknownDescription,
                        ),
                    )
                    .padding(
                        size.s16,
                    )
                    .padding(
                        .top,
                        toolbarHeight,
                    )
                    .padding(
                        .bottom,
                        bottomHeight,
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                    )
                    .accessibilityIdentifier(
                        "webDocument.failed",
                    )
                default:
                    WebDocumentContentView(
                        state: viewModel.state,
                        topInset: toolbarHeight,
                        bottomInset: bottomHeight,
                    )
                    .edgesIgnoringSafeArea(
                        .bottom,
                    )
                }
            },
            bottom: {
                WebDocumentBottomView()
            },
        )
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
